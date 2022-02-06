import subprocess

subprocess.run(["elm", "make", "src/Main.elm", "--output", "app.js"], cwd = "app")
subprocess.run(["cargo", "build"])
