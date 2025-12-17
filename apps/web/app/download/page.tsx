import { Header } from "@/components/landing/Header";
import Footer from "@/components/landing/Footer";

export default function DownloadPage() {
    return (
        <main className="flex min-h-screen flex-col">
            <Header />
            <div className="flex flex-1 flex-col items-center justify-center p-4 text-center">
                <h1 className="mb-4 text-4xl font-bold tracking-tight">Download HallPals</h1>
                <p className="max-w-md text-lg text-neutral-600 dark:text-neutral-400">
                    The HallPals mobile app is coming soon to the App Store. Stay tuned for updates!
                </p>
            </div>
            <Footer />
        </main>
    );
}
