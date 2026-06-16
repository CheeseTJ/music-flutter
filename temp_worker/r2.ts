export async function uploadToR2(
  bucket: R2Bucket,
  key: string,
  body: ArrayBuffer | Uint8Array | ReadableStream<Uint8Array>,
  contentType: string
): Promise<void> {
  await bucket.put(key, body, {
    httpMetadata: { contentType },
  });
}

export async function getFromR2(
  bucket: R2Bucket,
  key: string
): Promise<R2ObjectBody | null> {
  return bucket.get(key);
}

export async function getFromR2WithRange(
  bucket: R2Bucket,
  key: string,
  offset: number,
  length?: number
): Promise<R2ObjectBody | null> {
  return bucket.get(key, { range: { offset, length } });
}
