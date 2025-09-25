mkdir -p wrk
./zap-baseline.py -t https://www.storemesh.com -r zap-report-web.html -a > /zap/wrk/zap-web.log
curl -X POST https://example.com/upload/ -F "project=2" -F "file=@/zap/wrk/zap-web.log"
curl -X POST https://example.com/upload/ -F "project=2" -F "file=@/zap/wrk/zap-report-web.html"