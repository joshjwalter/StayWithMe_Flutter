Debug run: app + local request capture server

1) Open terminal A and go to project root:
cd /home/jjw368/Code/stay_with_me_flutter

2) Start server in foreground (easy to see logs):
python3 request_capture_server.py --host 127.0.0.1 --port 54010

3) Open terminal B and run app in Chrome:
cd /home/jjw368/Code/stay_with_me_flutter
flutter run -d chrome

4) In the app, go to Alarm page and press Start.
You should see request logs in terminal A.

Optional: run server in background instead
nohup python3 request_capture_server.py --host 127.0.0.1 --port 54010 > request-server.log 2>&1 &

Stop background server
pkill -f request_capture_server.py
