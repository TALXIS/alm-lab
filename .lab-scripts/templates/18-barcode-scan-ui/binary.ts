// A binary connector response comes back as a base64 string in the JSON envelope, not raw
// bytes - not something the generic executeAsync<TRequest, TResponse> typing can express.
export function toBytes(data: unknown): Uint8Array | null {
  if (typeof data !== "string") return null;
  try {
    const binary = atob(data);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return bytes;
  } catch {
    return null;
  }
}

// A code app's CSP allows img-src 'self' data: but not blob: - render bytes as a data: URI,
// not an object URL.
export function bytesToDataUrl(bytes: Uint8Array, mimeType: string): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return `data:${mimeType};base64,${btoa(binary)}`;
}
