local Url = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/AutoSpin.lua?t=" .. tostring(os.time())

loadstring(game:HttpGet(Url))()
