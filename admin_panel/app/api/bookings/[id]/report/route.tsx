/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable @typescript-eslint/no-unused-vars */
import { adminDb } from '@/lib/firebase-admin';
import { NextResponse } from 'next/server';
import React from 'react';
import fs from 'fs';
import path from 'path';

import {
    Document,
    Page,
    Text,
    View,
    StyleSheet,
    renderToBuffer,
    Image,
    Font,
} from '@react-pdf/renderer';
import { format } from 'date-fns';

// Create styles
const styles = StyleSheet.create({
    page: {
        padding: 30,
        fontFamily: 'Helvetica',
    },
    header: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        marginBottom: 20,
    },
    brand: {
        fontSize: 24,
        fontWeight: 'bold',
        color: '#7C3AED',
    },
    logo: {
        width: 100,
        height: 30,
        objectFit: 'contain',
        marginBottom: 4,
    },
    subtitle: {
        fontSize: 12,
        color: '#666',
    },
    bookingId: {
        fontSize: 10,
        textAlign: 'right',
    },
    section: {
        marginBottom: 20,
    },
    sectionTitle: {
        fontSize: 12,
        fontWeight: 'bold',
        backgroundColor: '#E5E7EB',
        padding: 4,
        paddingLeft: 8,
        marginBottom: 8,
    },
    row: {
        flexDirection: 'row',
        marginBottom: 4,
        fontSize: 10,
    },
    label: {
        width: 120,
        fontWeight: 'bold',
    },
    value: {
        flex: 1,
    },
    table: {
        display: 'flex',
        width: 'auto',
        borderStyle: 'solid',
        borderWidth: 1,
        borderColor: '#E5E7EB',
        borderRightWidth: 0,
        borderBottomWidth: 0,
    },
    tableRow: {
        flexDirection: 'row',
        borderBottomWidth: 1,
        borderBottomColor: '#E5E7EB',
    },
    tableHeader: {
        backgroundColor: '#F3F4F6',
        fontWeight: 'bold',
    },
    tableCol: {
        borderStyle: 'solid',
        borderWidth: 1,
        borderLeftWidth: 0,
        borderTopWidth: 0,
        borderColor: '#E5E7EB',
        padding: 4,
    },
    areaCol: { width: '25%' },
    damageCol: { width: '15%' },
    notesCol: { width: '40%' },
    photoCol: { width: '20%' },
    cellText: {
        fontSize: 9,
    },
    newDamageRow: {
        backgroundColor: '#FEF2F2',
    },
    footer: {
        marginTop: 20,
        borderTopWidth: 1,
        borderTopColor: '#E5E7EB',
        paddingTop: 10,
    },
    certTitle: {
        fontSize: 10,
        fontWeight: 'bold',
        marginBottom: 4,
    },
    certText: {
        fontSize: 8,
        color: '#4B5563',
    },
    imageContainer: {
        width: 50,
        height: 50,
        justifyContent: 'center',
        alignItems: 'center',
        backgroundColor: '#F3F4F6',
        borderRadius: 4,
        overflow: 'hidden',
    },
    image: {
        width: '100%',
        height: '100%',
        objectFit: 'cover',
    },
});

const AREAS = [
    { id: 'front', label: 'Front Bumper & Hood' },
    { id: 'back', label: 'Rear Bumper & Trunk' },
    { id: 'left', label: 'Driver Side (Left)' },
    { id: 'right', label: 'Passenger Side (Right)' },
    { id: 'roof', label: 'Roof' },
    { id: 'interior', label: 'Interior & Seats' },
];

const getAreaLabel = (id: string) => AREAS.find(a => a.id === id)?.label || id;

// PDF Component
const TripReport = ({ booking, pre, post, claim, host, renter, car, generatedAt, logoBase64 }: any) => {
    const df = (d: any) => d ? format(new Date(d), 'MMM dd, yyyy HH:mm') : 'N/A';
    
    const renderInspectionTable = (items: any, preItems: any = null) => {
        if (!items) return null;
        
        return (
            <View style={styles.table}>
                <View style={styles.tableRow}>
                    <View style={[styles.tableCol, styles.areaCol, styles.tableHeader]}><Text style={styles.cellText}>Area</Text></View>
                    <View style={[styles.tableCol, styles.damageCol, styles.tableHeader]}><Text style={styles.cellText}>Damage</Text></View>
                    <View style={[styles.tableCol, styles.notesCol, styles.tableHeader]}><Text style={styles.cellText}>Notes</Text></View>
                    <View style={[styles.tableCol, styles.photoCol, styles.tableHeader]}><Text style={styles.cellText}>Photo</Text></View>
                </View>
                {Object.keys(items).map((areaKey) => {
                    const item = items[areaKey];
                    const preItem = preItems ? preItems[areaKey] : null;
                    const isNewDamage = preItem && !preItem.hasDamage && item.hasDamage;
                    
                    return (
                        <View key={areaKey} style={[styles.tableRow, isNewDamage ? styles.newDamageRow : {}]}>
                            <View style={[styles.tableCol, styles.areaCol]}>
                                <Text style={styles.cellText}>{getAreaLabel(areaKey)}</Text>
                            </View>
                            <View style={[styles.tableCol, styles.damageCol]}>
                                <Text style={[styles.cellText, { color: isNewDamage ? 'red' : (item.hasDamage ? 'orange' : 'black') }]}>
                                    {item.hasDamage ? (isNewDamage ? 'NEW DAMAGE' : 'YES') : 'NO'}
                                </Text>
                            </View>
                            <View style={[styles.tableCol, styles.notesCol]}>
                                <Text style={styles.cellText}>{item.notes || '-'}</Text>
                            </View>
                            <View style={[styles.tableCol, styles.photoCol]}>
                                {item.photoUrls && item.photoUrls.length > 0 ? (
                                    <View style={styles.imageContainer}>
                                        <Image src={item.photoUrls[0]} style={styles.image} />
                                    </View>
                                ) : (
                                    <Text style={[styles.cellText, { color: '#9CA3AF' }]}>No photo</Text>
                                )}
                            </View>
                        </View>
                    );
                })}
            </View>
        );
    };

    return (
        <Document>
            <Page size="A4" style={styles.page}>
                {/* Header */}
                <View style={styles.header}>
                    <View>
                        {logoBase64 ? (
                            <Image src={logoBase64} style={styles.logo} />
                        ) : (
                            <Text style={styles.brand}>RozRides</Text>
                        )}
                        <Text style={styles.subtitle}>Trip Inspection Report</Text>
                    </View>
                    <View>
                        <Text style={styles.bookingId}>BOOKING ID</Text>
                        <Text style={styles.bookingId}>{booking.id.toUpperCase()}</Text>
                    </View>
                </View>

                {/* Section 1: Trip Summary */}
                <View style={styles.section}>
                    <Text style={styles.sectionTitle}>1. TRIP SUMMARY</Text>
                    <View style={styles.row}>
                        <Text style={styles.label}>Car</Text>
                        <Text style={styles.value}>{`${car.year} ${car.brand} ${car.model} (${car.carNumber || 'N/A'})`}</Text>
                    </View>
                    <View style={styles.row}>
                        <Text style={styles.label}>Host</Text>
                        <Text style={styles.value}>{host.fullName}</Text>
                    </View>
                    <View style={styles.row}>
                        <Text style={styles.label}>Renter</Text>
                        <Text style={styles.value}>{`${renter.fullName} (CNIC: ${renter.cnic?.number || 'N/A'})`}</Text>
                    </View>
                    <View style={styles.row}>
                        <Text style={styles.label}>Pickup Date</Text>
                        <Text style={styles.value}>{df(booking.startDate)}</Text>
                    </View>
                    <View style={styles.row}>
                        <Text style={styles.label}>Return Date</Text>
                        <Text style={styles.value}>{df(booking.endDate)}</Text>
                    </View>
                </View>

                {/* Section 2: Pre-Trip Inspection */}
                {pre && (
                    <View style={styles.section}>
                        <Text style={styles.sectionTitle}>2. PRE-TRIP INSPECTION</Text>
                        <View style={styles.row}><Text style={styles.label}>Security Deposit</Text><Text style={styles.value}>PKR {pre.depositCollected?.toLocaleString()}</Text></View>
                        <View style={styles.row}><Text style={styles.label}>Fuel Level</Text><Text style={styles.value}>{pre.fuelLevel}</Text></View>
                        <View style={styles.row}><Text style={styles.label}>Odometer</Text><Text style={styles.value}>{pre.odometerReading} km</Text></View>
                        <View style={styles.row}><Text style={styles.label}>Handover Time</Text><Text style={styles.value}>{df(pre.completedAt)}</Text></View>
                        <View style={{ marginTop: 10 }}>
                            {renderInspectionTable(pre.items)}
                        </View>
                    </View>
                )}

                {/* Section 3: Post-Trip Inspection */}
                {post && (
                    <View style={styles.section}>
                        <Text style={styles.sectionTitle}>3. POST-TRIP INSPECTION</Text>
                        <View style={styles.row}><Text style={styles.label}>Fuel Level</Text><Text style={styles.value}>{post.fuelLevel}</Text></View>
                        <View style={styles.row}><Text style={styles.label}>Odometer</Text><Text style={styles.value}>{post.odometerReading} km</Text></View>
                        <View style={styles.row}><Text style={styles.label}>Distance Driven</Text><Text style={styles.value}>{post.kmDriven} km</Text></View>
                        <View style={styles.row}><Text style={styles.label}>Return Time</Text><Text style={styles.value}>{df(post.completedAt)}</Text></View>
                        <View style={{ marginTop: 10 }}>
                            {renderInspectionTable(post.items, pre?.items)}
                        </View>
                    </View>
                )}

                {/* Section 4: Dispute Record */}
                {claim && (
                    <View style={styles.section}>
                        <Text style={styles.sectionTitle}>4. DISPUTE RECORD</Text>
                        <View style={styles.row}><Text style={styles.label}>Dispute Status</Text><Text style={styles.value}>{claim.status.toUpperCase()}</Text></View>
                        <View style={styles.row}><Text style={styles.label}>Admin Decision</Text><Text style={styles.value}>{claim.adminDecision?.toUpperCase() || 'PENDING'}</Text></View>
                        <View style={styles.row}><Text style={styles.label}>Final Deduction</Text><Text style={styles.value}>PKR {claim.finalDeductionAmount?.toLocaleString() || '0'}</Text></View>
                        {claim.extraChargeAmount > 0 && (
                            <View style={styles.row}><Text style={styles.label}>Extra Charge</Text><Text style={{...styles.value, color: 'red'}}>PKR {claim.extraChargeAmount.toLocaleString()}</Text></View>
                        )}
                        <View style={styles.row}><Text style={styles.label}>Admin Notes</Text><Text style={styles.value}>{claim.adminNotes || 'No notes provided.'}</Text></View>
                        <View style={styles.row}><Text style={styles.label}>Resolved At</Text><Text style={styles.value}>{df(claim.resolvedAt)}</Text></View>
                    </View>
                )}

                {/* Section 5: Certification */}
                <View style={styles.footer}>
                    <Text style={styles.certTitle}>PLATFORM CERTIFICATION</Text>
                    <Text style={styles.certText}>Generated at: {df(generatedAt)}</Text>
                    <Text style={styles.certText}>This report reflects data recorded in real-time by both parties on the RozRides platform. All photos and signatures were captured and stored securely by RozRides.</Text>
                    <Text style={{...styles.certText, marginTop: 10, textAlign: 'center', fontWeight: 'bold', color: '#7C3AED'}}>© 2026 RozRides - Peer-to-Peer Car Rentals</Text>
                </View>
            </Page>
        </Document>
    );
};

export async function GET(
    request: Request,
    { params }: { params: { id: string } }
) {
    const bookingId = params.id;

    try {
        // Fetch all data
        const results = await Promise.all([
            adminDb.collection('bookings').doc(bookingId).get(),
            adminDb.collection('bookings').doc(bookingId).collection('inspections').doc('pre_trip').get(),
            adminDb.collection('bookings').doc(bookingId).collection('inspections').doc('post_trip').get(),
            adminDb.collection('damageClaims').where('bookingId', '==', bookingId).get(),
        ]);

        const bookingSnap = results[0];
        const preSnap = results[1];
        const postSnap = results[2];
        const claimsSnap = results[3];

        if (!bookingSnap.exists) {
            return NextResponse.json({ error: 'Booking not found' }, { status: 404 });
        }

        const bookingData = bookingSnap.data() as any;
        const booking: any = { id: bookingSnap.id, ...bookingData };
        // Handle timestamps
        const serializeDate = (d: any) => d?.toDate() || null;
        booking.startDate = serializeDate(bookingData.startDate);
        booking.endDate = serializeDate(bookingData.endDate);

        const pre = preSnap.exists ? { ...preSnap.data() as any, completedAt: serializeDate((preSnap.data() as any)?.completedAt) } : null;
        const post = postSnap.exists ? { ...postSnap.data() as any, completedAt: serializeDate((postSnap.data() as any)?.completedAt) } : null;
        const claimDoc = claimsSnap.docs[0];
        const claim = claimDoc ? { ...claimDoc.data() as any, id: claimDoc.id, resolvedAt: serializeDate((claimDoc.data() as any)?.resolvedAt) } : null;

        const [hostSnap, renterSnap, carSnap] = await Promise.all([
            adminDb.collection('users').doc(bookingData.hostId).get(),
            adminDb.collection('users').doc(bookingData.renterId).get(),
            adminDb.collection('listings').doc(bookingData.carId).get(),
        ]);

        const host = hostSnap.data();
        const renter = renterSnap.data();
        const car = carSnap.data();

        let logoBase64 = '';
        try {
            const logoPath = path.join(process.cwd(), 'public', 'logo.png');
            const logoBuffer = fs.readFileSync(logoPath);
            logoBase64 = "data:image/png;base64," + logoBuffer.toString('base64');
        } catch(e) {
            console.error('Could not load logo', e);
        }

        // Generate PDF
        const buffer = await renderToBuffer(
            <TripReport 
                booking={booking} 
                pre={pre} 
                post={post} 
                claim={claim} 
                host={host} 
                renter={renter} 
                car={car}
                generatedAt={new Date()}
                logoBase64={logoBase64}
            />
        );

        return new Response(buffer as unknown as BodyInit, {
            headers: {
                'Content-Type': 'application/pdf',
                'Content-Disposition': `attachment; filename="RozRides_Report_${bookingId.substring(0, 8)}.pdf"`,
            },
        });
    } catch (error) {
        console.error('Error generating report:', error);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
