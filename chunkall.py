from llmsherpa.readers import LayoutPDFReader
import os
import re

llmsherpa_api_url = "http://localhost:5010/api/parseDocument?renderFormat=all"
baseinpath = "/home/halilprometa/Desktop/bitirme/documents"
base_path = "/home/halilprometa/Desktop/bitirme/chunks"

def process_pdf(pdf_path):
    file_name = os.path.basename(pdf_path)
    file_name_without_ext = os.path.splitext(file_name)[0]
    parts = file_name_without_ext.split('-')
    file_name_only = '-'.join(parts[:-2])
    cleaned_name = file_name_only.replace('-', ' ')
    cleaned_name = re.sub(r'\s+', ' ', cleaned_name)
    cleaned_name = cleaned_name.strip()

    print(f"Tam dosya adı: {file_name}")
    print(f"Temizlenmiş isim: {cleaned_name}")

    pdf_reader = LayoutPDFReader(llmsherpa_api_url)
    doc = pdf_reader.read_pdf(pdf_path)

    output_name = file_name_without_ext + ".txt"
    output_path = os.path.join(base_path, output_name)
    with open(output_path, "w") as f:
        for chunk in doc.chunks():
            f.write(f"\n----------\n")
            f.write(chunk.to_context_text())
    print("Çıktı kaydedildi:", output_path)
    print("Chunk sayısı:", len(doc.chunks()))

def process_all_pdfs():
    for file in os.listdir(baseinpath):
        if file.lower().endswith(".pdf"):
            pdf_path = os.path.join(baseinpath, file)
            process_pdf(pdf_path)

if __name__ == "__main__":
    process_all_pdfs()