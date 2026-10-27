"""Supported launcher. Configure environment explicitly before launching."""
import argparse
import uvicorn

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", default=".env.demo")
    parser.add_argument("--port", type=int, default=8007)
    args = parser.parse_args()
    uvicorn.run("src.main:app", env_file=args.env_file, host="127.0.0.1", port=args.port,
                proxy_headers=False, access_log=False)


#Start this from the terminal to start the server
