try (
    fileIn @"H:\新软件\3D脚本\片窗\片窗+.ms"
    format "PCH_VALIDATE_OK\n"
) catch (
    format "PCH_VALIDATE_ERROR: %\n" (getCurrentException())
)
quitMAX #noPrompt
