import { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy - HallPals",
  description: "Privacy Policy for HallPals mobile application",
};

export default function PrivacyPolicyPage() {
  return (
    <div className="min-h-screen bg-white">
      <div className="max-w-4xl mx-auto px-4 py-12 sm:px-6 lg:px-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-8">Privacy Policy for HallPals</h1>

        <p className="text-sm text-gray-500 mb-8">Last Updated: December 15, 2024</p>

        <section className="prose prose-gray max-w-none">
          <h2>Introduction</h2>
          <p>
            HallPals (&quot;we,&quot; &quot;our,&quot; or &quot;us&quot;) is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application HallPals (the &quot;App&quot;).
          </p>
          <p>
            Please read this Privacy Policy carefully. By using the App, you agree to the collection and use of information in accordance with this policy.
          </p>

          <h2>Information We Collect</h2>

          <h3>Information You Provide to Us</h3>

          <h4>Account Information</h4>
          <ul>
            <li>Name</li>
            <li>Email address</li>
            <li>University affiliation</li>
            <li>Role (Resident Assistant or Resident)</li>
            <li>Hall/floor assignment</li>
          </ul>

          <h4>Profile Information</h4>
          <ul>
            <li>Profile photo (optional)</li>
            <li>Room number</li>
            <li>Contact preferences</li>
          </ul>

          <h4>Communication Data</h4>
          <ul>
            <li>Direct messages sent through the App</li>
            <li>Group chat messages</li>
            <li>Content you share in conversations</li>
          </ul>

          <h4>Duty and Task Data (for Resident Assistants)</h4>
          <ul>
            <li>Rounds logs and timestamps</li>
            <li>Room check records</li>
            <li>Meeting notes with residents</li>
            <li>Task completion status</li>
            <li>Incident reports</li>
          </ul>

          <h4>Reports and Submissions</h4>
          <ul>
            <li>Noise reports</li>
            <li>Feedback submissions</li>
          </ul>

          <h3>Information Collected Automatically</h3>

          <h4>Device Information</h4>
          <ul>
            <li>Device type and model</li>
            <li>Operating system version</li>
            <li>Unique device identifiers</li>
            <li>App version</li>
          </ul>

          <h4>Usage Information</h4>
          <ul>
            <li>Features accessed</li>
            <li>Time spent in the App</li>
            <li>Actions taken within the App</li>
          </ul>

          <h4>Push Notification Tokens</h4>
          <ul>
            <li>Firebase Cloud Messaging (FCM) tokens for delivering notifications</li>
          </ul>

          <h3>Information from Third-Party Services</h3>

          <h4>Firebase Authentication</h4>
          <ul>
            <li>We use Firebase Authentication to securely manage user sign-in</li>
            <li>Authentication tokens and session data</li>
          </ul>

          <h4>Firebase Cloud Firestore</h4>
          <ul>
            <li>We store user data, messages, and app content in Firebase Cloud Firestore</li>
          </ul>

          <h2>How We Use Your Information</h2>
          <p>We use the information we collect to:</p>
          <ul>
            <li><strong>Provide and maintain the App</strong> - Enable core features like messaging, duty tracking, and community management</li>
            <li><strong>Facilitate communication</strong> - Allow RAs and residents to communicate through direct messages and group chats</li>
            <li><strong>Send notifications</strong> - Deliver push notifications for new messages, duty reminders, and important updates</li>
            <li><strong>Improve the App</strong> - Analyze usage patterns to enhance features and user experience</li>
            <li><strong>Ensure safety</strong> - Enable incident reporting and emergency communication features</li>
            <li><strong>Provide AI assistance</strong> - Process queries to our AI assistant to help users find information about policies and procedures</li>
            <li><strong>Administrative purposes</strong> - Allow residence life staff to manage halls, assign RAs, and oversee community operations</li>
          </ul>

          <h2>Data Sharing and Disclosure</h2>
          <p>We do not sell your personal information. We may share your information in the following circumstances:</p>

          <h3>Within Your Institution</h3>
          <ul>
            <li>Your name, role, and hall assignment are visible to other users in your residence hall community</li>
            <li>Messages you send are visible to recipients</li>
            <li>RAs can see residents assigned to their floor/wing</li>
            <li>Residence Directors can see RAs and residents in their hall</li>
          </ul>

          <h3>Service Providers</h3>
          <ul>
            <li><strong>Google Firebase</strong> - For authentication, database storage, cloud functions, and push notifications</li>
            <li><strong>Google Cloud Platform</strong> - For hosting and infrastructure</li>
            <li><strong>gemini</strong> - For AI assistant functionality (queries are processed without personal identifiers)</li>
          </ul>

          <h3>Legal Requirements</h3>
          <p>We may disclose your information if required to do so by law or in response to valid requests by public authorities.</p>

          <h3>Safety and Security</h3>
          <p>We may disclose information when we believe it is necessary to investigate, prevent, or take action regarding potential violations of our policies, suspected fraud, or situations involving potential threats to the safety of any person.</p>

          <h2>Data Retention</h2>
          <p>We retain your personal information for as long as your account is active or as needed to provide you services. Specifically:</p>
          <ul>
            <li><strong>Account data</strong> - Retained while your account is active</li>
            <li><strong>Messages</strong> - Retained for the duration of the conversation</li>
            <li><strong>Duty logs and reports</strong> - Retained according to your institution&apos;s records retention policy</li>
            <li><strong>Push notification tokens</strong> - Deleted when you log out or uninstall the App</li>
          </ul>
          <p>You may request deletion of your account and associated data by contacting us at the email address below.</p>

          <h2>Data Security</h2>
          <p>We implement appropriate technical and organizational security measures to protect your personal information, including:</p>
          <ul>
            <li>Encryption of data in transit using TLS/SSL</li>
            <li>Encryption of data at rest in Firebase</li>
            <li>Secure authentication through Firebase Auth</li>
            <li>Role-based access controls</li>
            <li>Regular security assessments</li>
          </ul>
          <p>However, no method of transmission over the Internet or electronic storage is 100% secure, and we cannot guarantee absolute security.</p>

          <h2>Your Rights and Choices</h2>

          <h3>Access and Update</h3>
          <p>You can access and update your profile information within the App settings.</p>

          <h3>Push Notifications</h3>
          <p>You can disable push notifications through your device settings at any time.</p>

          <h3>Account Deletion</h3>
          <p>You may request deletion of your account by contacting us. Upon deletion, we will remove your personal information, though some information may be retained as required by law or for legitimate business purposes.</p>

          <h3>Data Portability</h3>
          <p>You may request a copy of your personal data by contacting us.</p>

          <h2>Children&apos;s Privacy</h2>
          <p>The App is intended for use by college and university students and staff. We do not knowingly collect personal information from children under 13. If you believe we have collected information from a child under 13, please contact us immediately.</p>

          <h2>Third-Party Links</h2>
          <p>The App may contain links to third-party websites and services, including campus resources, mental health services, and reporting tools. We are not responsible for the privacy practices of these third parties. We encourage you to read their privacy policies.</p>

          <h2>Changes to This Privacy Policy</h2>
          <p>We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy in the App and updating the &quot;Last Updated&quot; date. You are advised to review this Privacy Policy periodically for any changes.</p>

          <h2>Contact Us</h2>
          <p>If you have questions or concerns about this Privacy Policy or our data practices, please contact us at:</p>
          <p>
            <strong>Email:</strong> privacy@hallpals.com
          </p>
          <p>
            <strong>Mailing Address:</strong><br />
            HallPals<br />
            University of St. Thomas<br />
            2115 Summit Avenue<br />
            St. Paul, MN 55105
          </p>

          <h2>California Privacy Rights</h2>
          <p>If you are a California resident, you have additional rights under the California Consumer Privacy Act (CCPA), including the right to know what personal information we collect, the right to delete your personal information, and the right to opt-out of the sale of your personal information (we do not sell personal information).</p>

          <h2>International Users</h2>
          <p>If you are accessing the App from outside the United States, please be aware that your information may be transferred to, stored, and processed in the United States where our servers are located. By using the App, you consent to this transfer.</p>

          <hr className="my-8" />
          <p className="text-sm text-gray-500"><strong>Effective Date:</strong> December 15, 2024</p>
        </section>
      </div>
    </div>
  );
}
