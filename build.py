import subprocess

print("elm make src/Main.elm --output app.js")
subprocess.run(["elm", "make", "src/Main.elm", "--output", "app.js"], cwd = "app")
print("cargo build")
subprocess.run(["cargo", "build"])
