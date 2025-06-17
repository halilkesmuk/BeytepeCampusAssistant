from chromadb import PersistentClient
from chromadb.utils import embedding_functions
from openai import OpenAI

def get_relevant_chunks(query: str, n_results: int = 5):
    """
    Vector database'den en alakalı chunk'ları getirir.
    """
    # Embedding fonksiyonunu oluştur
    embedding_function = embedding_functions.SentenceTransformerEmbeddingFunction(
        model_name="paraphrase-multilingual-MiniLM-L12-v2"
    )
    
    # ChromaDB istemcisini oluştur
    client = PersistentClient(path="chroma_db")
    
    # Koleksiyona eriş
    collection = client.get_collection(
        name="processed-docs-tr",
        embedding_function=embedding_function
    )
    
    # Sorgu yap
    results = collection.query(
        query_texts=[query],
        n_results=n_results
    )
    
    # Sonuçları birleştir
    relevant_chunks = []
    for doc, metadata in zip(results['documents'][0], results['metadatas'][0]):
        relevant_chunks.append({
            "text": doc,
            "source": metadata['source'],
            "chunk_index": metadata['chunk_index']
        })
    
    return relevant_chunks

def create_prompt(query: str, relevant_chunks: list):
    """
    LLM için prompt oluşturur.
    """
    # Chunk'ları birleştir
    context = "\n\n".join([f"Kaynak: {chunk['source']}\nMetin: {chunk['text']}" for chunk in relevant_chunks])
    
    print(f"\n##### Bağlam:\n{context}\n #####\n")

    # Prompt şablonu
    prompt = f""" 
    Sen Hacettepe Bilgisayar Bilimleri Mühendisliği bölümündeki öğrencilere yardım eden bir yapay zeka asistanısın.
    Aşağıdaki soru ve sana gelen bağlamdan yola çıkarak en iyi yanıtı ver.
    Yanıtta başka herhangi bir bilgi ekleme, sadece verilen bağlamdan yola çıkarak yanıt ver.
    Yanıtın kesin ve doğru olmalıdır. Yanıtın sonunda kaynakları belirtmelisin.
    Her zaman Türkçe yanıt ver.

Bağlam:
{context}

Soru: {query}

Yanıt:"""
    
    return prompt

def get_llm_response(prompt: str):
    """
    OpenRouter API kullanarak LLM'den yanıt alır.
    """
    # OpenAI istemcisini oluştur
    client = OpenAI(
        base_url="https://openrouter.ai/api/v1",
        api_key="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",
    )
    
    # Yanıtı al
    completion = client.chat.completions.create(
        model="mistralai/mistral-small-3.1-24b-instruct:free",
        messages=[
            {
                "role": "user",
                "content": prompt
            }
        ]
    )
    
    return completion.choices[0].message.content

def answer_question(query: str):
    """
    Soruyu yanıtlar.
    """
    # İlgili chunk'ları al
    relevant_chunks = get_relevant_chunks(query)
    
    # Prompt oluştur
    prompt = create_prompt(query, relevant_chunks)
    
    # LLM'den yanıt al
    response = get_llm_response(prompt)
    
    # Sonuçları göster
    print("\nSoru:", query)
    print("\nKullanılan Kaynaklar:")
    for chunk in relevant_chunks:
        print(f"- {chunk['source']} (Chunk {chunk['chunk_index']})")
    print("\nYanıt:", response)

def smart_chunk_text(text, chunk_size=500, overlap=100):
    import re
    lines = [l.strip() for l in text.split('\n') if l.strip()]
    chunks = []
    buffer = ""
    for line in lines:
        if re.match(r'^[A-ZÇĞİÖŞÜ].*:$', line):  # Başlık gibi satır
            if buffer:
                chunks.append(buffer.strip())
                buffer = ""
            buffer += line + "\n"
        else:
            buffer += line + " "
            if len(buffer) > chunk_size:
                chunks.append(buffer.strip())
                buffer = ""
    if buffer.strip():
        chunks.append(buffer.strip())
    # Çok kısa chunkları birleştir
    merged_chunks = []
    temp = ""
    for chunk in chunks:
        if len(temp) + len(chunk) < chunk_size // 2:
            temp += " " + chunk
        else:
            if temp:
                merged_chunks.append(temp.strip())
            temp = chunk
    if temp:
        merged_chunks.append(temp.strip())
    # Çok uzun chunkları böl
    final_chunks = []
    for chunk in merged_chunks:
        start = 0
        while start < len(chunk):
            end = min(start + chunk_size, len(chunk))
            final_chunks.append(chunk[start:end].strip())
            start += chunk_size - overlap
    return final_chunks

if __name__ == "__main__":
    while True:
        query = input("\nSormak istediğiniz soruyu girin (çıkmak için 'q' yazın): ")
        if query.lower() == 'q':
            break
        answer_question(query)