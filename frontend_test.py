import urllib.request
try:
    resp = urllib.request.urlopen('http://localhost:8080/presentation.html')
    if resp.getcode() == 200:
        print("Frontend OK")
    else:
        print(f"Error {resp.getcode()}")
except Exception as e:
    print(f"Exception: {e}")
