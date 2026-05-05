import { NextResponse } from 'next/server';
import { GoogleGenerativeAI } from '@google/generative-ai';

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '');

export async function POST(
    request: Request,
    { params }: { params: { claimId: string } }
) {
    try {
        if (!process.env.GEMINI_API_KEY) {
            return NextResponse.json({ error: 'Gemini API key not configured' }, { status: 500 });
        }

        const body = await request.json();
        const { claimDetails, preTrip, postTrip, messages } = body;

        const model = genAI.getGenerativeModel({ model: "gemini-flash-latest" });

        const prompt = `
Act as an impartial car rental dispute resolution expert. 
You are given data from a car rental dispute.
Your job is to analyze the discrepancy between pre-trip and post-trip damages, read the chat for context, and provide a fair recommendation based on evidence.

Here is the data:
Host Claim Description: ${claimDetails.description || 'None'}
Host Claimed Amount: PKR ${claimDetails.hostClaimedAmount || 0}
Deposit Amount: PKR ${claimDetails.depositAmount || 0}

Pre-Trip Inspection:
${JSON.stringify(preTrip, null, 2)}

Post-Trip Inspection:
${JSON.stringify(postTrip, null, 2)}

Chat History between Host and Renter:
${JSON.stringify(messages, null, 2)}

Provide your recommendation as a JSON object with the following schema exactly (no markdown wrapping):
{
  "recommendation": "host" | "renter" | "split" | "extra",
  "reasoning": "A clear, professional explanation of your findings. Use bullet points (with a dash -) and short paragraphs to make it highly readable. Use explicit newline characters (\\n) for line breaks.",
  "suggestedSplitAmount": number (Optional: if 'split', suggest an amount for the host to keep from the deposit. If 'extra', suggest an amount for the renter to pay over the deposit. Otherwise 0.)
}

If no new damage is found in the post-trip vs pre-trip and chat doesn't prove damage, side with "renter".
If clear physical damage is new and substantial, side with "host".
If it's minor, wear and tear, or cleaning issue, consider "split".
If it's related to late return or severe abuse requiring more than the deposit, consider "extra".
`;

        const result = await model.generateContent(prompt);
        const responseText = result.response.text();
        
        // Try to parse the JSON output from the AI
        let jsonOutput = null;
        try {
            // Strip potential markdown JSON formatting
            const cleanText = responseText.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
            jsonOutput = JSON.parse(cleanText);
        } catch (e) {
            console.error("Failed to parse Gemini response as JSON:", responseText);
            throw new Error("AI returned invalid format");
        }

        return NextResponse.json(jsonOutput);

    } catch (error: any) {
        console.error('Error in AI analysis route:', error);
        return NextResponse.json(
            { error: error.message || 'Failed to analyze claim' },
            { status: 500 }
        );
    }
}
