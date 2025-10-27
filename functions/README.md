# ReMind Cloud Functions

## Required secrets
Set the Twilio credentials before deploying:

```
firebase functions:secrets:set TWILIO_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase functions:secrets:set TWILIO_FROM
```

## Local development
```
cd functions
npm install
npm run build
firebase emulators:start
```

## Deployment
```
cd functions
npm run build
firebase deploy --only functions
```

## Data schema
The export flow first reads entries from `users/{uid}/entries`. If that collection is empty it falls back to the legacy `entries` collection filtered by `userId == uid` so both layouts are supported.

## Security
Secrets are never committed. Twilio credentials are loaded from `functions:secrets` at runtime.

## Testing the callable locally
With the emulators running you can invoke the callable using curl (replace $PROJECT with your project ID):

```
curl -X POST \
  http://localhost:5001/$PROJECT/us-central1/exportHistoryPdf \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(firebase auth:print-access-token)" \
  -d '{"data":{}}'
```

The response includes the `success`, `mediaUrl`, and `errorMessage` fields described above.
