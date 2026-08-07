import { S3Client, PutBucketCorsCommand, PutObjectCommand } from "@aws-sdk/client-s3";

const accountId = process.env.R2_ACCOUNT_ID;
const bucket = process.env.R2_BUCKET_NAME;
const publicBase = (process.env.R2_PUBLIC_URL || "").replace(/\/$/, "");
const accessKeyId = process.env.R2_ACCESS_KEY_ID;
const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;

if (!accountId || !bucket || !publicBase || !accessKeyId || !secretAccessKey) {
  console.error("MISSING_ENV");
  process.exit(1);
}

const client = new S3Client({
  region: "auto",
  endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  credentials: { accessKeyId, secretAccessKey },
});

await client.send(
  new PutBucketCorsCommand({
    Bucket: bucket,
    CORSConfiguration: {
      CORSRules: [
        {
          AllowedOrigins: ["*"],
          AllowedMethods: ["GET", "HEAD"],
          AllowedHeaders: ["*"],
          ExposeHeaders: [
            "ETag",
            "Content-Length",
            "Content-Type",
            "Content-Range",
            "Accept-Ranges",
          ],
          MaxAgeSeconds: 3600,
        },
      ],
    },
  }),
);
console.log("CORS_OK");

const key = `ilanlar/_health/${Date.now()}.txt`;
await client.send(
  new PutObjectCommand({
    Bucket: bucket,
    Key: key,
    Body: Buffer.from("engelsizclub-r2-ok"),
    ContentType: "text/plain",
  }),
);
console.log("PUT_OK");

const url = `${publicBase}/${key}`;
const res = await fetch(url);
console.log("PUBLIC_STATUS", res.status);
console.log("PUBLIC_BODY", (await res.text()).slice(0, 40));
console.log("PUBLIC_URL_SAMPLE", url);
