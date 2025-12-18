import React from "react";

export default function PrivacyPage() {
  return (
    <main className="container mx-auto px-6 py-12 max-w-4xl">
      <article className="prose prose-slate max-w-none">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Privacy Policy</h1>
        <p className="text-gray-500 text-sm mb-8">Last Updated: December 17, 2025</p>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">Introduction</h2>
          <p className="text-gray-700 leading-relaxed">
            HallPals (&quot;we,&quot; &quot;our,&quot; or &quot;us&quot;) is committed to protecting your privacy. This Privacy Policy
            explains how we collect, use, disclose, and safeguard your information when you use the HallPals
            mobile application (the &quot;App&quot;). Please read this policy carefully. By using the App, you consent
            to the practices described in this Privacy Policy.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">Information We Collect</h2>

          <h3 className="text-lg font-medium text-gray-800 mt-6 mb-3">Personal Information You Provide</h3>
          <p className="text-gray-700 leading-relaxed mb-3">
            When you create an account and use the App, we may collect:
          </p>
          <ul className="list-disc pl-6 text-gray-700 space-y-2">
            <li><strong>Account Information:</strong> Name, email address, and university affiliation provided during sign-in</li>
            <li><strong>Profile Information:</strong> Your role (resident, RA, or staff), hall assignment, floor, and room number</li>
            <li><strong>Communications:</strong> Messages you send to other users, reports you submit, and feedback you provide</li>
            <li><strong>Media:</strong> Photos you choose to capture or upload when using the App</li>
            <li><strong>AI Interactions:</strong> Questions and prompts you submit to our AI assistant feature</li>
          </ul>

          <h3 className="text-lg font-medium text-gray-800 mt-6 mb-3">Information Collected Automatically</h3>
          <p className="text-gray-700 leading-relaxed mb-3">
            When you use the App, we automatically collect:
          </p>
          <ul className="list-disc pl-6 text-gray-700 space-y-2">
            <li><strong>Device Information:</strong> Device type, operating system version, and app version</li>
            <li><strong>Usage Data:</strong> Features accessed, interactions within the App, and general usage patterns</li>
            <li><strong>Push Notification Tokens:</strong> Identifiers used to deliver notifications to your device</li>
          </ul>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">How We Use Your Information</h2>
          <p className="text-gray-700 leading-relaxed mb-3">We use the information we collect to:</p>
          <ul className="list-disc pl-6 text-gray-700 space-y-2">
            <li>Provide, operate, and maintain the App and its features</li>
            <li>Facilitate communication between residents and residence life staff</li>
            <li>Deliver push notifications about important updates, messages, and alerts</li>
            <li>Power our AI assistant to help answer your residence life questions</li>
            <li>Support safety reporting and residence life administrative functions</li>
            <li>Improve the App and develop new features</li>
            <li>Respond to your inquiries and provide customer support</li>
            <li>Comply with legal obligations and protect our rights</li>
          </ul>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">AI Assistant Feature</h2>
          <p className="text-gray-700 leading-relaxed mb-3">
            The App includes an AI assistant powered by Google Cloud Vertex AI (Gemini). When you use this feature:
          </p>
          <ul className="list-disc pl-6 text-gray-700 space-y-2">
            <li>Your questions are transmitted to Google&apos;s servers for processing</li>
            <li>Conversations are not permanently stored and exist only for the duration of your session</li>
            <li>The AI is designed to provide information about residence life topics only</li>
            <li>We recommend not sharing sensitive personal information (such as Social Security numbers, financial information, or medical details) with the AI assistant</li>
          </ul>
          <p className="text-gray-700 leading-relaxed mt-3">
            Google&apos;s use of your data is governed by their privacy policy and terms of service.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">Camera and Photo Library Access</h2>
          <p className="text-gray-700 leading-relaxed">
            The App may request permission to access your device&apos;s camera and photo library. This access is used
            solely to allow you to attach images to messages, reports, or other App features. We only access your
            camera or photos when you explicitly choose to take or select an image. We do not access, scan, or
            analyze your photo library without your direct action.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">Push Notifications</h2>
          <p className="text-gray-700 leading-relaxed">
            With your permission, we send push notifications to keep you informed about messages, alerts, and
            important updates. You can disable push notifications at any time through your device&apos;s settings.
            Disabling notifications will not affect other App functionality.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">Third-Party Services</h2>
          <p className="text-gray-700 leading-relaxed mb-3">
            We use the following third-party services to operate the App:
          </p>
          <ul className="list-disc pl-6 text-gray-700 space-y-2">
            <li><strong>Firebase Authentication:</strong> For secure user sign-in and identity management</li>
            <li><strong>Firebase Cloud Firestore:</strong> For storing and synchronizing App data</li>
            <li><strong>Firebase Cloud Messaging:</strong> For delivering push notifications</li>
            <li><strong>Google Cloud Vertex AI:</strong> For powering the AI assistant feature</li>
          </ul>
          <p className="text-gray-700 leading-relaxed mt-3">
            These services are provided by Google and are subject to Google&apos;s Privacy Policy.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">How We Share Your Information</h2>
          <p className="text-gray-700 leading-relaxed mb-3">
            <strong>We do not sell your personal information.</strong> We may share your information in the following circumstances:
          </p>
          <ul className="list-disc pl-6 text-gray-700 space-y-2">
            <li><strong>Within Your Institution:</strong> With residence life staff and administrators at your university as necessary to provide App functionality and support residence life operations</li>
            <li><strong>Service Providers:</strong> With third-party vendors who assist us in operating the App, subject to confidentiality obligations</li>
            <li><strong>Legal Requirements:</strong> When required by law, legal process, or to protect the rights, property, or safety of HallPals, our users, or others</li>
            <li><strong>With Your Consent:</strong> In other circumstances where we have obtained your explicit consent</li>
          </ul>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">Data Security</h2>
          <p className="text-gray-700 leading-relaxed">
            We implement industry-standard security measures to protect your information, including encrypted
            data transmission (TLS/SSL), secure authentication protocols, and access controls. However, no
            method of electronic transmission or storage is 100% secure, and we cannot guarantee absolute
            security.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">Data Retention</h2>
          <p className="text-gray-700 leading-relaxed">
            We retain your information for as long as your account is active or as needed to provide you with
            the App&apos;s services. We may also retain certain information as required by law or for legitimate
            business purposes, such as resolving disputes or enforcing our agreements.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">Your Rights and Choices</h2>
          <p className="text-gray-700 leading-relaxed mb-3">You have the following rights regarding your information:</p>
          <ul className="list-disc pl-6 text-gray-700 space-y-2">
            <li><strong>Access:</strong> View and update your profile information within the App</li>
            <li><strong>Notifications:</strong> Enable or disable push notifications through your device settings</li>
            <li><strong>Permissions:</strong> Grant or revoke camera and photo library access through your device settings</li>
            <li><strong>Account Deletion:</strong> Request deletion of your account and associated data by contacting us or using the delete account feature in the App</li>
          </ul>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">Children&apos;s Privacy</h2>
          <p className="text-gray-700 leading-relaxed">
            The App is intended for university students and staff who are typically 18 years of age or older.
            We do not knowingly collect personal information from children under 13 years of age. If you believe
            we have inadvertently collected information from a child under 13, please contact us immediately so
            we can delete such information.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">International Data Transfers</h2>
          <p className="text-gray-700 leading-relaxed">
            Your information may be transferred to and processed in the United States, where our servers and
            service providers are located. By using the App, you consent to the transfer and processing of
            your information in the United States and other jurisdictions that may have different data
            protection laws than your country of residence.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">Third-Party Links</h2>
          <p className="text-gray-700 leading-relaxed">
            The App may contain links to third-party websites or services. We are not responsible for the
            privacy practices of these third parties. We encourage you to review the privacy policies of
            any third-party services you access through the App.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">Changes to This Privacy Policy</h2>
          <p className="text-gray-700 leading-relaxed">
            We may update this Privacy Policy from time to time. When we make changes, we will update the
            &quot;Last Updated&quot; date at the top of this page. We encourage you to review this Privacy Policy
            periodically. Your continued use of the App after any changes constitutes your acceptance of
            the updated Privacy Policy.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">Contact Us</h2>
          <p className="text-gray-700 leading-relaxed mb-4">
            If you have any questions about this Privacy Policy, wish to exercise your privacy rights, or
            have concerns about how we handle your information, please contact us:
          </p>
          <div className="bg-gray-50 rounded-lg p-6">
            <p className="text-gray-700 mb-2"><strong>Email:</strong> oligurmessa@gmail.com</p>
            <p className="text-gray-700 mb-0">
              <strong>Mail:</strong> HallPals<br />
              University of St. Thomas<br />
              2115 Summit Avenue<br />
              St. Paul, MN 55105
            </p>
          </div>
        </section>

        <div className="border-t border-gray-200 pt-6 mt-12">
          <p className="text-gray-500 text-sm">
            Effective Date: December 17, 2025
          </p>
        </div>
      </article>
    </main>
  );
}
