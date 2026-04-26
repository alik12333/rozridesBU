import { getFlaggedReviews, dismissReviewFlag, deleteReview } from '@/lib/firestore';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Flag, Trash2, CheckCircle2, Star } from 'lucide-react';
import { revalidatePath } from 'next/cache';

export const dynamic = 'force-dynamic';

export default async function ReviewsPage() {
    // Currently fetching only flagged reviews. We could add a filter parameter later
    // to fetch all reviews.
    const reviews = await getFlaggedReviews();

    async function handleDismiss(formData: FormData) {
        'use server';
        const reviewId = formData.get('reviewId') as string;
        if (reviewId) {
            await dismissReviewFlag(reviewId);
            revalidatePath('/dashboard/reviews');
        }
    }

    async function handleDelete(formData: FormData) {
        'use server';
        const reviewId = formData.get('reviewId') as string;
        if (reviewId) {
            await deleteReview(reviewId);
            revalidatePath('/dashboard/reviews');
        }
    }

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-4xl font-bold mb-2">Review Moderation</h1>
                <p className="text-muted-foreground">Manage user reviews and handle flagged content</p>
            </div>

            <Card className={reviews.length > 0 ? "border-orange-500 shadow-sm shadow-orange-200" : ""}>
                <CardHeader>
                    <CardTitle className={`flex items-center gap-2 ${reviews.length > 0 ? "text-orange-600" : ""}`}>
                        <Flag className="w-5 h-5" />
                        Flagged Reviews ({reviews.length})
                    </CardTitle>
                    <CardDescription>
                        Reviews that have been flagged by users or automated filters for moderation.
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    <div className="rounded-md border">
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    <TableHead>Date</TableHead>
                                    <TableHead>Reviewer</TableHead>
                                    <TableHead>Type</TableHead>
                                    <TableHead>Rating</TableHead>
                                    <TableHead className="w-1/3">Comment</TableHead>
                                    <TableHead className="text-right">Actions</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {reviews.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={6} className="text-center text-muted-foreground py-8">
                                            <CheckCircle2 className="w-12 h-12 text-green-500 mx-auto mb-3" />
                                            No flagged reviews. You're all caught up!
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    reviews.map((review) => (
                                        <TableRow key={review.id}>
                                            <TableCell className="text-muted-foreground whitespace-nowrap">
                                                {new Date(review.createdAt).toLocaleDateString()}
                                            </TableCell>
                                            <TableCell className="font-medium whitespace-nowrap">
                                                {review.reviewerName}
                                            </TableCell>
                                            <TableCell>
                                                <Badge variant="outline">
                                                    {review.type.replace(/_/g, ' ').toUpperCase()}
                                                </Badge>
                                            </TableCell>
                                            <TableCell>
                                                <div className="flex items-center gap-1 font-bold">
                                                    {review.overallRating}
                                                    <Star className="w-4 h-4 text-yellow-500 fill-yellow-500" />
                                                </div>
                                            </TableCell>
                                            <TableCell className="text-sm">
                                                <span className="line-clamp-2" title={review.comment}>
                                                    {review.comment}
                                                </span>
                                            </TableCell>
                                            <TableCell className="text-right">
                                                <div className="flex justify-end gap-2">
                                                    <form action={handleDismiss}>
                                                        <input type="hidden" name="reviewId" value={review.id} />
                                                        <Button variant="outline" size="sm" type="submit" className="text-green-600 border-green-200 hover:bg-green-50">
                                                            Dismiss
                                                        </Button>
                                                    </form>
                                                    <form action={handleDelete}>
                                                        <input type="hidden" name="reviewId" value={review.id} />
                                                        <Button variant="destructive" size="sm" type="submit">
                                                            <Trash2 className="w-4 h-4 mr-1" /> Delete
                                                        </Button>
                                                    </form>
                                                </div>
                                            </TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </div>
                </CardContent>
            </Card>
        </div>
    );
}
