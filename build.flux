uses proc.exec, fs.write;

let certo = "C:/Users/robert/Desktop/Certo/target/release/certo.exe";

let checkResult = exec([certo, "check", "src/lume.cto"], "2m")?;
if checkResult.success {
    let compileResult = exec([certo, "src/lume.cto", "-o", "dist/lume.exe"], "10m")?;
    if compileResult.success {
        let apiResult = exec(["dist/lume.exe", "api"], "1m")?;
        if apiResult.success {
            write("ai/lume-api.json", apiResult.stdout)?;
            "wrote dist/lume.exe"
        } else {
            "api manifest generation failed: " + apiResult.stderr
        }
    } else {
        "compile failed: " + compileResult.stderr
    }
} else {
    "check failed: " + checkResult.stderr
}
