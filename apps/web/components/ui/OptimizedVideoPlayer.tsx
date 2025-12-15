"use client";

import { useEffect, useRef } from "react";

interface OptimizedVideoPlayerProps {
  src: string;
  className?: string;
}

export function OptimizedVideoPlayer({
  src,
  className = "",
}: OptimizedVideoPlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    // Set video attributes for optimization
    video.playsInline = true;
    video.muted = true;
    video.loop = true;
    video.autoplay = true;
    video.preload = "auto";

    // Try to play the video
    const playPromise = video.play();
    if (playPromise !== undefined) {
      playPromise.catch(() => {
        // Autoplay was prevented, which is fine
      });
    }
  }, []);

  return (
    <video
      ref={videoRef}
      className={className}
      src={src}
      playsInline
      muted
      loop
      autoPlay
      preload="auto"
    />
  );
}

