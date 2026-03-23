local Url = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/Init.luau?t=" .. tostring(os.time())

loadstring(game:HttpGet(Url))()
