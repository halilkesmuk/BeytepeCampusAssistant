from llmsherpa.readers import LayoutPDFReader
import os
import re


llmsherpa_api_url = "http://localhost:5010/api/parseDocument?renderFormat=all"
#llmsherpa_api_url = "https://readers.llmsherpa.com/api/document/developer/parseDocument?renderFormat=all"

baseinpath = "/home/halilprometa/Desktop/bitirme/documents"
pdf_path = os.path.join(baseinpath, "ai-dersler.pdf")

# Dosya adını al
file_name = os.path.basename(pdf_path)

# Dosya adını işle
file_name_without_ext = os.path.splitext(file_name)[0]  # .pdf uzantısını kaldır
parts = file_name_without_ext.split('-')
file_name_only = '-'.join(parts[:-2])  # Son iki parçayı çıkarıp kalanları birleştir

# Tire işaretlerini boşluğa çevir ve çoklu boşlukları temizle
cleaned_name = file_name_only.replace('-', ' ')  # Tireleri boşluğa çevir
cleaned_name = re.sub(r'\s+', ' ', cleaned_name)  # Çoklu boşlukları tek boşluğa indir
cleaned_name = cleaned_name.strip()  # Baş ve sondaki boşlukları temizle

print(f"Tam dosya adı: {file_name}")
print(f"Temizlenmiş isim: {cleaned_name}")

pdf_reader = LayoutPDFReader(llmsherpa_api_url)
doc = pdf_reader.read_pdf(pdf_path)

temp = 0
output_name = file_name_without_ext + ".txt"
base_path = "/home/halilprometa/Desktop/bitirme/chunks"

output_path = os.path.join(base_path, output_name)
with open(output_path, "w") as f:
    for chunk in doc.chunks():
        #print('-'*100)
        #print(dir(chunk))
        #print(chunk.page_idx)
        f.write(f"\n----------\n")   # 10 tane -
        f.write(chunk.to_context_text())
        #print(chunk.to_text())
print("cikti kaydedildi")
print("chunk sayisi: ", len(doc.chunks()))


#print(doc)