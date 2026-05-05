import { NextRequest, NextResponse } from 'next/server';
import { adminDb } from '@/lib/firebase-admin';
import { GoogleGenerativeAI } from '@google/generative-ai';

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '');

export async function POST(
    req: NextRequest,
    { params }: { params: { id: string } }
) {
    try {
        const userId = params.id;
        if (!process.env.GEMINI_API_KEY) {
            return NextResponse.json({ error: 'Gemini API key not configured' }, { status: 500 });
        }

        const userDoc = await adminDb.collection('users').doc(userId).get();
        if (!userDoc.exists) {
            return NextResponse.json({ error: 'User not found' }, { status: 404 });
        }

        const userData = userDoc.data();
        const cnic = userData?.cnic;

        if (!cnic || !cnic.frontImage) {
            return NextResponse.json({ error: 'CNIC front image missing' }, { status: 400 });
        }

        const model = genAI.getGenerativeModel({ model: "gemini-flash-latest" });

        // Fetch image and convert to base64 with timeout
        let imageBase64: string;
        let mimeType: string = "image/jpeg";
        
        try {
            console.log(`Starting AI Verification for user: ${userId}, fetching image: ${cnic.frontImage}`);
            
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 15000); // 15 second timeout

            const imageRes = await fetch(cnic.frontImage, { signal: controller.signal });
            clearTimeout(timeoutId);

            if (!imageRes.ok) throw new Error(`Storage returned ${imageRes.status}: ${imageRes.statusText}`);
            
            const contentType = imageRes.headers.get('content-type');
            if (contentType) mimeType = contentType;
            
            const imageBuffer = await imageRes.arrayBuffer();
            if (imageBuffer.byteLength === 0) throw new Error("Image buffer is empty");
            
            imageBase64 = Buffer.from(imageBuffer).toString('base64');
            console.log(`Image fetched successfully, size: ${imageBuffer.byteLength} bytes`);
        } catch (fetchError: any) {
            console.error('Network or Storage Error:', fetchError);
            const isTimeout = fetchError.name === 'AbortError';
            return NextResponse.json({ 
                error: isTimeout ? 'Image fetch timed out' : 'Storage network error', 
                details: fetchError.message 
            }, { status: 502 });
        }

        const prompt = `
            You are an OCR expert specialized in Pakistani CNIC (Computerized National Identity Card) documents.
            Analyze the provided image and extract the 13-digit CNIC number.
            The number is usually in the format XXXXX-XXXXXXX-X.
            Return your answer strictly as a JSON object with no other text:
            {"cnicNumber": "XXXXX-XXXXXXX-X"}
            If you cannot find a valid CNIC number, return:
            {"error": "Could not find a valid CNIC number in the image"}
        `;

        const result = await model.generateContent([
            prompt,
            {
                inlineData: {
                    data: imageBase64,
                    mimeType: mimeType
                }
            }
        ]);

        const responseText = result.response.text();
        
        // Robust JSON parsing
        let extracted;
        try {
            const cleanJson = responseText.replace(/```json|```/g, '').trim();
            extracted = JSON.parse(cleanJson);
        } catch (parseError) {
            console.error('Failed to parse AI response:', responseText);
            // Fallback attempt to find something that looks like a CNIC number in the text
            const cnicRegex = /\d{5}-\d{7}-\d{1}/;
            const match = responseText.match(cnicRegex);
            if (match) {
                extracted = { cnicNumber: match[0] };
            } else {
                return NextResponse.json({ error: 'AI returned an unreadable response format', details: responseText }, { status: 500 });
            }
        }

        if (extracted.error) {
            return NextResponse.json({ error: extracted.error }, { status: 422 });
        }

        const extractedNumber = extracted.cnicNumber.replace(/\D/g, '');
        const providedNumber = cnic.number.replace(/\D/g, '');

        const matches = extractedNumber === providedNumber;

        return NextResponse.json({
            extractedNumber: extracted.cnicNumber,
            providedNumber: cnic.number,
            matches,
        });

    } catch (error: any) {
        console.error('Error verifying CNIC with AI:', error);
        return NextResponse.json({ 
            error: 'AI verification failed', 
            details: error.message 
        }, { status: 500 });
    }
}
