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
Act as an elite, impartial car rental dispute resolution expert operating in Pakistan.
You are reviewing a damage/dispute claim between a car Host and a Renter.
Your job is to analyze the discrepancy between pre-trip and post-trip inspections, read the chat history for context, cross-reference the host's claim, and provide a fair recommendation based on objective evidence.

Here is the data:
Host Claim Description: ${claimDetails.description || 'None'}
Host Claimed Amount: PKR ${claimDetails.hostClaimedAmount || 0}
Security Deposit Amount: PKR ${claimDetails.depositAmount || 0}

Pre-Trip Inspection:
${JSON.stringify(preTrip, null, 2)}

Post-Trip Inspection:
${JSON.stringify(postTrip, null, 2)}

Chat History:
${JSON.stringify(messages, null, 2)}

### CONTEXT: RESOLUTION OPTIONS
You must recommend one of the following four actions, matching the Admin Dashboard buttons exactly:

1. "renter" (SIDE WITH RENTER): 
   - Meaning: The host's claim is invalid, unproven, pre-existing, or normal wear and tear.
   - Outcome: Renter gets their full deposit back.

2. "host" (SIDE WITH HOST):
   - Meaning: The host's claim is completely valid and accurate.
   - Outcome: Host gets exactly what they claimed/asked for. (This is deducted from the renter's deposit).

3. "split" (APPLY SPLIT):
   - Meaning: The damage or cleaning issue is valid but minor. The repair cost is LESS than the full Security Deposit.
   - Outcome: You must suggest a specific amount (PKR) to deduct from the deposit for the host. The renter gets the rest back.

4. "extra" (APPLY EXTRA CHARGE):
   - Meaning: The damage or loss is severe and significantly EXCEEDS the Security Deposit. 
   - Outcome: The host keeps the full deposit, AND you must suggest the additional amount (PKR) the renter must pay on top of losing the deposit.

### CONTEXT: PAKISTANI MARKET ESTIMATES (PKR)
Use these baseline estimates to judge if the host's claimed amount is realistic, or to calculate your own suggested split/extra amounts:
- Fuel: 401 PKR per Liter for Petrol, 500 PKR per Liter for Diesel. (A quarter tank missing is roughly 10-15 Liters, so ~4,000 - 7,500 PKR).
- Basic Car Wash: 500 - 1,000 PKR.
- Deep Interior Cleaning (stains, spills, smoking odors): 3,000 - 5,000 PKR.
- Minor Scratch Buffing/Compound: 1,500 - 3,000 PKR.
- Single Panel Repaint (bumper, fender, door due to deep scratch/dent): 8,000 - 15,000 PKR.
- Major Denting + Painting: 15,000 - 25,000+ PKR per panel.
- Interior Cigarette Burn on Seat: 2,000 - 4,000 PKR.
- Broken plastic trim / AC Vent: 3,000 - 8,000 PKR.

### INSTRUCTIONS
1. Look for definitive proof of new damage by comparing Pre-Trip and Post-Trip notes. Include fuel drops in your damage calculation.
2. Read the chat. Did the renter admit fault? Did the host mention it immediately?
3. Calculate the TRUE TOTAL COST of all valid damages and missing fuel based on the market estimates above.
4. IMPORTANT: Do NOT simply accept the host's Claimed Amount if your calculated true cost is higher. The host is forced to enter a value and might underestimate. If the true total cost significantly EXCEEDS the Security Deposit, you MUST choose the "extra" recommendation and suggest the remainder, ignoring the host's lower requested amount.
5. Output your recommendation strictly as a JSON object (no markdown wrapping) using this schema:

{
  "recommendation": "host" | "renter" | "split" | "extra",
  "reasoning": "A highly detailed, professional explanation of your findings. Reference specific evidence (or lack thereof), compare the claimed amount to market realities, and justify your chosen outcome. Use bullet points (with a dash -) and short paragraphs to make it highly readable. Use explicit newline characters (\\n) for line breaks.",
  "suggestedSplitAmount": number (Required if recommendation is 'split' or 'extra'. Put 0 if 'host' or 'renter'.)
}
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
