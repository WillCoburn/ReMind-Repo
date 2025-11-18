App Goal: I want to make an app where people can type in and submit their epiphones/affirmations/moments of clarity when they have them, which will then be texted to them at a randomized time in the future. The goal is for people to be reminded of pieces of wisdom and self-encouragement they had at a randomized time (between 9am and midnight some day in the near future (1-6 months)), hopefully when they might most need it. I will call the app ReMind. I want it to be a very simple UI and a fun tool for people with mood swings.

UI basics: I want a clean, new, modern UI with one screen. It should have a text bar in the middle to input moments of clarity/affirmation when they come, a small arrow to the right to submit them, and a envelope Icon in the top right to request an email pdf of all inputs. The app will need an onboarding screen to get phone number and will need to be able to send text messages.

Core features: The app should be able to do the following things:
      1. Create an account associated with the phone number
      2. Receive input and store for each account in the cloud
      3. Once 10 phrases have been submitted, start texting them back to the user. Still deciding how to handle frequency. 
      4. Compile and send all inputs to user in an SMS pdf if they request
      5. Data handling: Save data in the cloud and send the user their own inputs via SMS in the future 
      6. Allow user to insantly send themself a random affirmation from their records
      7. Show an 'affirmations bank' count (this should flash red and remind user they are out of affirmations when they try to text themselves one)
      
Extras Iphone only, simple, modern UI colors and design

## Developer "god mode" for Community

The Community feed now supports a developer-only "god mode" so you can stress test
the experience without tripping daily or per-post limits.

1. Use the Firebase Admin script to set the custom `godMode` claim on your test
   account:
   ```bash
   cd functions
   # Ensure GOOGLE_APPLICATION_CREDENTIALS points to a service account with auth.admin permissions
   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json npm run godmode -- <YOUR_FIREBASE_UID> on
   ```
   Run the same command with `off` to remove the override.
2. Sign out/in (or restart the app) so the iOS client refreshes its ID token.
3. When the banner appears on the Community tab you can:
   * create unlimited posts per 24h window,
   * tap like repeatedly to add as many likes as you need, and
   * file unlimited reports.

The override is enforced server-side via Firebase Auth custom claims, so regular
users cannot grant it to themselves.
