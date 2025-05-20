# ERPNext / Frappe Bench image (Python 3.10, Node 18)
FROM frappe/bench:latest    # immer aktuell

USER root

# Install poppler-utils für PDF-OCR (später nützlich, optional)
RUN apt-get update && apt-get install -y poppler-utils && apt-get clean
