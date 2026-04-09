# shreshthaggarwal.com

Personal website of Shreshth Agarwal — Founder, Hub4Estate.

## Stack

Static HTML. No frameworks, no build step. Just clean HTML + CSS.

## Deploy

Hosted on AWS S3 + CloudFront.

```bash
chmod +x deploy.sh
./deploy.sh
```

## Files

```
index.html      — Main page
404.html        — Error page
favicon.svg     — Favicon
robots.txt      — Search engine directives
sitemap.xml     — Sitemap for Google
security.txt    — Security contact (.well-known)
deploy.sh       — AWS S3 deploy script
photo.jpg       — Profile photo (add manually)
```

## Security Headers (via CloudFront)

- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Content-Security-Policy: default-src 'self'; style-src 'self' 'unsafe-inline' fonts.googleapis.com; font-src fonts.gstatic.com; img-src 'self' data:; script-src 'self' 'unsafe-inline'`
- `Permissions-Policy: camera=(), microphone=(), geolocation=()`
