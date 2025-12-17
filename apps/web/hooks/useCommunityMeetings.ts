import { useState, useEffect } from "react";
import { collection, query, orderBy, onSnapshot, doc, setDoc, deleteDoc, updateDoc, getDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";

export interface MeetingTopic {
    id: string;
    name: string;
    description: string;
    isCompleted: boolean;
}

export interface CommunityMeeting {
    id: string;
    title: string;
    description: string;
    scheduledDate: string; // ISO date string YYYY-MM-DDTHH:mm
    status: 'upcoming' | 'completed';
    topics: MeetingTopic[];
    notes: string;
    createdAt?: any;
    updatedAt?: any;
}

export function useCommunityMeetings(hallId: string | null) {
    const [meetings, setMeetings] = useState<CommunityMeeting[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!hallId) {
            setLoading(false);
            return;
        }

        const q = query(
            collection(db, "halls", hallId, "community_meetings"),
            orderBy("createdAt", "desc")
        );

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const data = snapshot.docs.map((doc) => ({
                id: doc.id,
                ...doc.data(),
            })) as CommunityMeeting[];
            setMeetings(data);
            setLoading(false);
        });

        return () => unsubscribe();
    }, [hallId]);

    // Create a new meeting
    const createMeeting = async (data: {
        title: string;
        description: string;
        scheduledDate: string;
        topics: { name: string; description: string }[];
    }) => {
        if (!hallId) return;

        const topicsWithIds: MeetingTopic[] = data.topics.map((topic, index) => ({
            id: `topic-${index}`,
            name: topic.name,
            description: topic.description,
            isCompleted: false
        }));

        const newRef = doc(collection(db, "halls", hallId, "community_meetings"));
        await setDoc(newRef, {
            title: data.title,
            description: data.description,
            scheduledDate: data.scheduledDate,
            status: 'upcoming',
            topics: topicsWithIds,
            notes: '',
            createdAt: new Date(),
            updatedAt: new Date()
        });

        return newRef.id;
    };

    // Update meeting
    const updateMeeting = async (meetingId: string, data: Partial<CommunityMeeting>) => {
        if (!hallId) return;
        await updateDoc(doc(db, "halls", hallId, "community_meetings", meetingId), {
            ...data,
            updatedAt: new Date()
        });
    };

    // Update meeting status
    const updateMeetingStatus = async (meetingId: string, status: 'upcoming' | 'completed') => {
        if (!hallId) return;
        await updateDoc(doc(db, "halls", hallId, "community_meetings", meetingId), {
            status,
            updatedAt: new Date()
        });
    };

    // Toggle topic completion
    const toggleTopicCompletion = async (meetingId: string, topicId: string) => {
        if (!hallId) return;

        const meetingRef = doc(db, "halls", hallId, "community_meetings", meetingId);
        const meetingSnap = await getDoc(meetingRef);

        if (!meetingSnap.exists()) return;

        const meetingData = meetingSnap.data();
        const topics = meetingData.topics as MeetingTopic[];

        const updatedTopics = topics.map(topic =>
            topic.id === topicId
                ? { ...topic, isCompleted: !topic.isCompleted }
                : topic
        );

        await updateDoc(meetingRef, {
            topics: updatedTopics,
            updatedAt: new Date()
        });
    };

    // Update meeting notes
    const updateMeetingNotes = async (meetingId: string, notes: string) => {
        if (!hallId) return;
        await updateDoc(doc(db, "halls", hallId, "community_meetings", meetingId), {
            notes,
            updatedAt: new Date()
        });
    };

    // Delete a meeting
    const deleteMeeting = async (meetingId: string) => {
        if (!hallId) return;
        await deleteDoc(doc(db, "halls", hallId, "community_meetings", meetingId));
    };

    // Get stats
    const upcomingMeetings = meetings.filter(m => m.status === 'upcoming');
    const completedMeetings = meetings.filter(m => m.status === 'completed');

    // Next meeting (upcoming, sorted by date)
    const nextMeeting = upcomingMeetings
        .filter(m => m.scheduledDate && new Date(m.scheduledDate) > new Date())
        .sort((a, b) => new Date(a.scheduledDate).getTime() - new Date(b.scheduledDate).getTime())[0];

    return {
        meetings,
        upcomingMeetings,
        completedMeetings,
        nextMeeting,
        loading,
        createMeeting,
        updateMeeting,
        updateMeetingStatus,
        toggleTopicCompletion,
        updateMeetingNotes,
        deleteMeeting
    };
}
