import os
from glob import glob
from chromadb import PersistentClient
from chromadb.utils import embedding_functions
import re

# === PARAMETRELER ===
CHUNK_SIZE =800      # karakter cinsinden chunk boyutu (optimum: 350-500)
CHUNK_OVERLAP = 150   # karakter cinsinden overlap (optimum: 50-100)
TXT_DIR = "processed-docs-tr"  # chunklanacak txt dosyalarının olduğu klasör
CHROMA_PATH = "chroma_db"  # ChromaDB dizini
COLLECTION_NAME = "processed-docs-tr"  # Koleksiyon adı

def smart_chunk_text(text, chunk_size=CHUNK_SIZE, overlap=CHUNK_OVERLAP):
    # Paragrafları koruyarak chunkla
    paragraphs = [p.strip() for p in re.split(r'\n{2,}', text) if p.strip()]
    chunks = []
    for para in paragraphs:
        start = 0
        while start < len(para):
            end = min(start + chunk_size, len(para))
            chunk = para[start:end]
            if chunk.strip():
                chunks.append(chunk.strip())
            start += chunk_size - overlap
    return chunks

def main():
    # Embedding fonksiyonu
    embedding_function = embedding_functions.SentenceTransformerEmbeddingFunction(
        model_name="paraphrase-multilingual-MiniLM-L12-v2"
        #model_name="all-MiniLM-L6-v2"
    )

    # ChromaDB istemcisi
    client = PersistentClient(path=CHROMA_PATH)
    # Koleksiyon oluştur veya al
    if COLLECTION_NAME in [c.name for c in client.list_collections()]:
        client.delete_collection(COLLECTION_NAME)
    collection = client.get_or_create_collection(
        name=COLLECTION_NAME,
        embedding_function=embedding_function
    )

    # Tüm txt dosyalarını oku ve chunkla
    txt_files = glob(os.path.join(TXT_DIR, "*.txt"))
    all_chunks = []
    metadatas = []
    ids = []
    for file_path in txt_files:
        with open(file_path, "r", encoding="utf-8") as f:
            text = f.read()
        file_name = os.path.basename(file_path)
        chunks = smart_chunk_text(text)
        for idx, chunk in enumerate(chunks):
            all_chunks.append(chunk)
            metadatas.append({"source": file_name, "chunk_index": idx})
            ids.append(f"{file_name}_{idx}")

    # ChromaDB'ye ekle
    print(f"{len(all_chunks)} adet chunk eklenecek...")
    collection.add(
        documents=all_chunks,
        metadatas=metadatas,
        ids=ids
    )
    print("Tüm chunklar başarıyla eklendi!")

if __name__ == "__main__":
    main()