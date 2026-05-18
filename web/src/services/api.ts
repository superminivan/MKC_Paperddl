import type { Category, Conference, ConferenceQuery } from "../types/conference";

const API_BASE = (import.meta.env.VITE_API_BASE as string) || "/api";

async function getJson<T>(url: string): Promise<T> {
  const response = await fetch(url, {
    credentials: "include"
  });
  if (!response.ok) {
    throw new Error(`Request failed: ${response.status}`);
  }
  return response.json() as Promise<T>;
}

export async function fetchCategories(): Promise<Category[]> {
  return getJson<Category[]>(`${API_BASE}/categories`);
}

export async function fetchConferences(query: ConferenceQuery): Promise<Conference[]> {
  const params = new URLSearchParams();
  if (query.sub) {
    const subValue = Array.isArray(query.sub) ? query.sub.join(",") : query.sub;
    params.set("sub", subValue);
  }
  if (query.q) params.set("q", query.q);
  const suffix = params.toString() ? `?${params.toString()}` : "";
  return getJson<Conference[]>(`${API_BASE}/conferences${suffix}`);
}

export async function addConference(conferenceData: any): Promise<any> {
  const res = await fetch(`${API_BASE}/conferences`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(conferenceData),
  });
  if (!res.ok) {
    const error = await res.json().catch(() => ({}));
    throw new Error(error.message || "Failed to add conference");
  }
  return res.json();

}

