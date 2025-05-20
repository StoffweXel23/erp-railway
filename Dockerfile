# -------- Dockerfile --------
FROM frappe/bench:5.19.0            # offizielles Bench-Image (Python 3.10, Node 18)
USER root

# Install poppler-utils für PDF-OCR (später nützlich, optional)
RUN apt-get update && apt-get install -y poppler-utils && apt-get clean
