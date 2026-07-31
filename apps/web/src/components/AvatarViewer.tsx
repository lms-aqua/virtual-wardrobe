"use client";

import { Canvas } from "@react-three/fiber";
import { Center, OrbitControls, useGLTF } from "@react-three/drei";
import { Suspense, useEffect, useState } from "react";

function Model({ url }: { url: string }) {
  const { scene } = useGLTF(url);
  return <primitive object={scene} />;
}

export default function AvatarViewer({ url }: { url: string }) {
  // Only render the WebGL canvas after mount (avoids SSR of three.js).
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  if (!mounted) {
    return <div className="h-[520px] w-full rounded-2xl border border-white/10 bg-black/20" />;
  }
  return (
    <div className="h-[520px] w-full overflow-hidden rounded-2xl border border-white/10 bg-black/20">
      <Canvas camera={{ position: [0, 0.9, 3], fov: 45 }} dpr={[1, 2]}>
        <ambientLight intensity={0.7} />
        <directionalLight position={[3, 6, 4]} intensity={1.4} />
        <directionalLight position={[-3, 2, -2]} intensity={0.5} />
        <Suspense fallback={null}>
          <Center>
            <Model url={url} />
          </Center>
        </Suspense>
        <OrbitControls enablePan={false} minDistance={1.2} maxDistance={6} target={[0, 0, 0]} />
      </Canvas>
    </div>
  );
}
