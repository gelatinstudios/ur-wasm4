
@echo off

..\odin-windows-amd64-dev-2023-05\odin.exe build source -vet -o:size -out:cart.wasm -target:freestanding_wasm32 -no-entry-point -extra-linker-flags:"--import-memory -zstack-size=14752 --initial-memory=65536 --max-memory=65536 --stack-first --lto-O3 --gc-sections --strip-all"
..\w4 bundle cart.wasm --title "The Royal Game of Ur" --html ur.html
