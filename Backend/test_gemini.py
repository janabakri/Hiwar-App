from google import genai

client = genai.Client(api_key="651f12b3c47bcd78d40358f2d134c9805c102cfb")   

try:
    response = client.models.generate_content(
        model="gemini-1.5-flash",
        contents="Say hello"
    )
    print("✅ Success:", response.text)
except Exception as e:
    print("❌ Error:", e)