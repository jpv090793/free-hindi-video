npx create-expo-app@latest frontend --template tabs --yes && \
cd frontend && \
npx expo install expo-image-picker expo-video expo-audio @expo/vector-icons react-native-safe-area-context && \
rm -rf "app/(tabs)"/* && \
mkdir -p src/api "app/(tabs)" && \
cat << 'EOF' > src/theme.ts
export const COLORS = {
  bg: "#0B1120",
  card: "#151F32",
  cardBorder: "#24324B",
  primary: "#F97316",
  primarySoft: "rgba(249, 115, 22, 0.16)",
  secondary: "#38BDF8",
  success: "#22C55E",
  danger: "#EF4444",
  text: "#F8FAFC",
  textMuted: "#94A3B8",
  inputBg: "#0F172A",
};
EOF
cat << 'EOF' > src/api/client.ts
import { Platform } from "react-native";

export interface VoiceItem {
  voice_id: string;
  name: string;
  gender: "male" | "female" | "other";
  style: string;
  preview_url?: string | null;
}

export interface TemplateItem {
  id: string;
  title: string;
  category: string;
  duration: string;
  aspect_ratio: "9:16" | "16:9";
  suggested_gender: "male" | "female";
  script: string;
}

export interface HistoryItem {
  id: string;
  title: string;
  script: string;
  voice_id: string;
  voice_name: string;
  aspect_ratio: string;
  media_type: "video" | "audio";
  video_url?: string;
  audio_url?: string;
  image_url?: string;
  slide_count?: number;
  subtitles_enabled?: boolean;
  created_at: string;
}

export interface HealthStatus {
  status: string;
  elevenlabs_configured: boolean;
  database_mode: string;
  ffmpeg_available: boolean;
}

let customBaseUrl = "";

export function setCustomBaseUrl(url: string) {
  customBaseUrl = url.replace(/\/+$/, "");
}

export function getApiBaseUrl(): string {
  if (customBaseUrl) return customBaseUrl;
  const envUrl = process.env.EXPO_PUBLIC_BACKEND_URL?.trim();
  if (envUrl) return envUrl.replace(/\/+$/, "");
  if (Platform.OS === "web" && typeof window !== "undefined") {
    return window.location.origin;
  }
  return "http://localhost:8001";
}

async function requestJson<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`${getApiBaseUrl()}${path}`, options);
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data?.detail || `सर्वर त्रुटि (${res.status})`);
  return data as T;
}

export const fetchHealth = () => requestJson<HealthStatus>("/api/health");
export const fetchTemplates = async () => (await requestJson<{ templates: TemplateItem[] }>("/api/templates")).templates || [];
export const fetchVoices = () => requestJson<{ voices: VoiceItem[]; source: string; elevenlabs_configured: boolean }>("/api/voices");
export const fetchHistory = async () => (await requestJson<{ items: HistoryItem[] }>("/api/history")).items || [];
export const deleteHistory = (id: string) => requestJson(`/api/history/${id}`, { method: "DELETE" });

export async function generateHindiVideo(params: {
  title: string;
  script: string;
  voice_id: string;
  voice_name: string;
  aspect_ratio: "9:16" | "16:9";
  enable_subtitles: boolean;
  subtitle_position: "bottom" | "center";
  imageUris: string[];
}): Promise<HistoryItem> {
  const formData = new FormData();
  formData.append("title", params.title);
  formData.append("script", params.script);
  formData.append("voice_id", params.voice_id);
  formData.append("voice_name", params.voice_name);
  formData.append("aspect_ratio", params.aspect_ratio);
  formData.append("enable_subtitles", String(params.enable_subtitles));
  formData.append("subtitle_position", params.subtitle_position);

  for (let i = 0; i < params.imageUris.length; i++) {
    const uri = params.imageUris[i];
    if (Platform.OS === "web") {
      const blob = await (await fetch(uri)).blob();
      formData.append("images", blob, `slide_${i}.jpg`);
    } else {
      formData.append("images", { uri, name: `slide_${i}.jpg`, type: "image/jpeg" } as unknown as Blob);
    }
  }

  const res = await fetch(`${getApiBaseUrl()}/api/generate`, { method: "POST", body: formData });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data?.detail || "वीडियो बनाने में समस्या आई।");
  return data.item as HistoryItem;
}
EOF
cat << 'EOF' > app/_layout.tsx
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { COLORS } from "../src/theme";

export default function RootLayout() {
  return (
    <SafeAreaProvider>
      <StatusBar style="light" backgroundColor={COLORS.bg} />
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="(tabs)" />
      </Stack>
    </SafeAreaProvider>
  );
}
EOF
cat << 'EOF' > "app/(tabs)/_layout.tsx"
import { Tabs } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { COLORS } from "../../src/theme";

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarStyle: { backgroundColor: COLORS.card, borderTopColor: COLORS.cardBorder, height: 64, paddingBottom: 8, paddingTop: 6 },
        tabBarActiveTintColor: COLORS.primary,
        tabBarInactiveTintColor: COLORS.textMuted,
      }}
    >
      <Tabs.Screen name="index" options={{ title: "होम", tabBarIcon: ({ color, size }) => <Ionicons name="home" color={color} size={size} /> }} />
      <Tabs.Screen name="create" options={{ title: "बनाएं", tabBarIcon: ({ color, size }) => <Ionicons name="sparkles" color={color} size={size} /> }} />
      <Tabs.Screen name="history" options={{ title: "हिस्ट्री", tabBarIcon: ({ color, size }) => <Ionicons name="film" color={color} size={size} /> }} />
      <Tabs.Screen name="profile" options={{ title: "प्रोफ़ाइल", tabBarIcon: ({ color, size }) => <Ionicons name="person" color={color} size={size} /> }} />
    </Tabs>
  );
}
EOF
cat << 'EOF' > app.json
{
  "expo": {
    "name": "Free Hindi Video",
    "slug": "free-hindi-video",
    "version": "1.0.0",
    "orientation": "portrait",
    "scheme": "freehindivideo",
    "userInterfaceStyle": "dark",
    "android": {
      "package": "com.freehindivideo.app",
      "versionCode": 1,
      "permissions": ["android.permission.READ_MEDIA_IMAGES", "android.permission.READ_EXTERNAL_STORAGE"]
    },
    "plugins": [
      "expo-router",
      ["expo-image-picker", { "photosPermission": "वीडियो स्लाइडशो के लिए फोटो चुनने की अनुमति दें।" }],
      "expo-video",
      "expo-audio"
    ]
  }
}
EOF
cat << 'EOF' > eas.json
{
  "cli": { "version": ">= 12.0.0" },
  "build": {
    "preview": {
      "distribution": "internal",
      "android": { "buildType": "apk" }
    }
  }
}
EOF