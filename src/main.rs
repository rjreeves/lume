use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};
use std::env;
use std::fs::{self, File};
use std::io::{self, BufReader};
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::time::{SystemTime, UNIX_EPOCH};
use walkdir::WalkDir;

const MANIFEST_VERSION: u32 = 1;

#[derive(Debug, Serialize, Deserialize)]
struct FileRecord {
    blake3: String,
    size: u64,
    modified_ns: u64,
}

#[derive(Debug, Serialize, Deserialize)]
struct Manifest {
    version: u32,
    algorithm: String,
    root: PathBuf,
    created_unix_seconds: u64,
    files: BTreeMap<String, FileRecord>,
    scan_errors: Vec<String>,
}

struct Options {
    root: PathBuf,
    manifest: Option<PathBuf>,
    update: bool,
}

fn usage() -> &'static str {
    "Usage: b3changes <root-folder> [--manifest <file>] [--update]\n\
     First run creates a baseline. Later runs report added, modified, and deleted files."
}

fn parse_args() -> Result<Options, String> {
    let mut args = env::args_os().skip(1);
    let Some(root) = args.next() else {
        return Err(usage().to_owned());
    };
    if root == "-h" || root == "--help" {
        println!("{}", usage());
        std::process::exit(0);
    }

    let mut manifest = None;
    let mut update = false;
    while let Some(arg) = args.next() {
        if arg == "--manifest" {
            manifest = Some(PathBuf::from(
                args.next().ok_or("--manifest requires a file path")?,
            ));
        } else if arg == "--update" {
            update = true;
        } else {
            return Err(format!(
                "Unknown argument: {}\n{}",
                arg.to_string_lossy(),
                usage()
            ));
        }
    }
    Ok(Options {
        root: root.into(),
        manifest,
        update,
    })
}

fn absolute(path: PathBuf) -> io::Result<PathBuf> {
    if path.is_absolute() {
        Ok(path)
    } else {
        Ok(env::current_dir()?.join(path))
    }
}

fn hash_file(path: &Path) -> io::Result<String> {
    let mut reader = BufReader::new(File::open(path)?);
    let mut hasher = blake3::Hasher::new();
    io::copy(&mut reader, &mut hasher)?;
    Ok(hasher.finalize().to_hex().to_string())
}

fn scan(root: &Path, manifest_path: &Path) -> (BTreeMap<String, FileRecord>, Vec<String>) {
    let mut files = BTreeMap::new();
    let mut errors = Vec::new();

    for entry in WalkDir::new(root).follow_links(false).sort_by_file_name() {
        let entry = match entry {
            Ok(value) => value,
            Err(error) => {
                errors.push(error.to_string());
                continue;
            }
        };
        if !entry.file_type().is_file() || entry.path() == manifest_path {
            continue;
        }
        let path = entry.path();
        let result = (|| -> io::Result<FileRecord> {
            let metadata = path.metadata()?;
            let modified_ns = metadata
                .modified()?
                .duration_since(UNIX_EPOCH)
                .unwrap_or_default()
                .as_nanos()
                .min(u64::MAX as u128) as u64;
            Ok(FileRecord {
                blake3: hash_file(path)?,
                size: metadata.len(),
                modified_ns,
            })
        })();
        match result {
            Ok(record) => {
                let relative = path
                    .strip_prefix(root)
                    .unwrap_or(path)
                    .to_string_lossy()
                    .replace('\\', "/");
                files.insert(relative, record);
            }
            Err(error) => errors.push(format!("{}: {error}", path.display())),
        }
    }
    (files, errors)
}

fn save_manifest(
    path: &Path,
    root: &Path,
    files: BTreeMap<String, FileRecord>,
    errors: Vec<String>,
) -> io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let manifest = Manifest {
        version: MANIFEST_VERSION,
        algorithm: "BLAKE3".to_owned(),
        root: root.to_owned(),
        created_unix_seconds: SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs(),
        files,
        scan_errors: errors,
    };
    let json = serde_json::to_vec_pretty(&manifest).map_err(io::Error::other)?;
    fs::write(path, json)
}

fn run() -> Result<u8, String> {
    let options = parse_args()?;
    let root = options.root.canonicalize().map_err(|error| {
        format!(
            "Cannot open root folder {}: {error}",
            options.root.display()
        )
    })?;
    if !root.is_dir() {
        return Err(format!("Root is not a folder: {}", root.display()));
    }
    let manifest_path = absolute(
        options
            .manifest
            .unwrap_or_else(|| root.join(".blake3-manifest.json")),
    )
    .map_err(|error| error.to_string())?;
    let (current, errors) = scan(&root, &manifest_path);

    if !manifest_path.exists() {
        let file_count = current.len();
        let error_count = errors.len();
        save_manifest(&manifest_path, &root, current, errors).map_err(|error| {
            format!("Cannot save manifest {}: {error}", manifest_path.display())
        })?;
        println!("BASELINE CREATED: {}", manifest_path.display());
        println!("Files hashed: {file_count}; errors: {error_count}");
        return Ok(if error_count > 0 { 2 } else { 0 });
    }

    let json = fs::read(&manifest_path)
        .map_err(|error| format!("Cannot read manifest {}: {error}", manifest_path.display()))?;
    let previous: Manifest = serde_json::from_slice(&json)
        .map_err(|error| format!("Invalid manifest {}: {error}", manifest_path.display()))?;
    if previous.version != MANIFEST_VERSION || previous.algorithm != "BLAKE3" {
        return Err("Unsupported manifest version or hashing algorithm".to_owned());
    }

    let old_names: BTreeSet<_> = previous.files.keys().collect();
    let new_names: BTreeSet<_> = current.keys().collect();
    let added: Vec<_> = new_names.difference(&old_names).copied().collect();
    let deleted: Vec<_> = old_names.difference(&new_names).copied().collect();
    let modified: Vec<_> = old_names
        .intersection(&new_names)
        .filter(|name| {
            let key = name.as_str();
            previous.files[key].blake3 != current[key].blake3
        })
        .copied()
        .collect();
    let unchanged = old_names.intersection(&new_names).count() - modified.len();

    for name in &added {
        println!("ADDED    {name}");
    }
    for name in &modified {
        println!("MODIFIED {name}");
    }
    for name in &deleted {
        println!("DELETED  {name}");
    }
    for error in &errors {
        eprintln!("ERROR    {error}");
    }
    println!(
        "Summary: {} added, {} modified, {} deleted, {} unchanged, {} errors",
        added.len(),
        modified.len(),
        deleted.len(),
        unchanged,
        errors.len()
    );

    let has_changes = !added.is_empty() || !modified.is_empty() || !deleted.is_empty();
    let error_count = errors.len();
    if options.update {
        save_manifest(&manifest_path, &root, current, errors).map_err(|error| {
            format!(
                "Cannot update manifest {}: {error}",
                manifest_path.display()
            )
        })?;
        println!("BASELINE UPDATED: {}", manifest_path.display());
    }
    Ok(if error_count > 0 {
        2
    } else if has_changes {
        1
    } else {
        0
    })
}

fn main() -> ExitCode {
    match run() {
        Ok(code) => ExitCode::from(code),
        Err(error) => {
            eprintln!("{error}");
            ExitCode::from(64)
        }
    }
}
