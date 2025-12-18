import React from "react";

export default function TermsPage() {
  return (
    <main className="container mx-auto px-6 py-12 max-w-4xl">
      <article className="prose prose-slate max-w-none">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Terms of Service</h1>
        <p className="text-gray-500 text-sm mb-8">Last Updated: December 17, 2025</p>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">1. Acceptance of Terms</h2>
          <p className="text-gray-700 leading-relaxed">
            By downloading, accessing, or using the HallPals mobile application (the &quot;App&quot;), you agree to be
            bound by these Terms of Service (the &quot;Terms&quot;). If you do not agree to these Terms, you must not
            use the App. These Terms constitute a legally binding agreement between you and HallPals.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">2. Description of Service</h2>
          <p className="text-gray-700 leading-relaxed mb-3">
            HallPals is a mobile application designed for university residence life communities. The App provides
            tools and features for:
          </p>
          <ul className="list-disc pl-6 text-gray-700 space-y-2">
            <li>Resident Assistants (RAs) to manage their floors and communicate with residents</li>
            <li>Residents to connect with their RA, report concerns, and access resources</li>
            <li>Residence life staff and housing administrators to oversee operations</li>
            <li>AI-powered assistance for residence life questions</li>
            <li>Emergency contact information and safety resources</li>
          </ul>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">3. Eligibility</h2>
          <p className="text-gray-700 leading-relaxed">
            You must be at least 18 years old or the age of majority in your jurisdiction to use the App.
            By using the App, you represent and warrant that you meet this eligibility requirement and that
            you are a current student, staff member, or authorized user affiliated with a participating
            university or institution.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">4. User Accounts</h2>
          <p className="text-gray-700 leading-relaxed mb-3">
            Certain features of the App require you to create or sign in to an account. When you create an account, you agree to:
          </p>
          <ul className="list-disc pl-6 text-gray-700 space-y-2">
            <li>Provide accurate, current, and complete information</li>
            <li>Maintain and promptly update your account information</li>
            <li>Keep your login credentials secure and confidential</li>
            <li>Notify us immediately of any unauthorized access to your account</li>
            <li>Accept full responsibility for all activities that occur under your account</li>
          </ul>
          <p className="text-gray-700 leading-relaxed mt-3">
            We reserve the right to suspend or terminate accounts that violate these Terms or contain inaccurate information.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">5. Acceptable Use</h2>
          <p className="text-gray-700 leading-relaxed mb-3">
            You agree to use the App only for lawful purposes and in accordance with these Terms. You agree NOT to:
          </p>
          <ul className="list-disc pl-6 text-gray-700 space-y-2">
            <li>Harass, threaten, intimidate, or abuse other users</li>
            <li>Post or transmit content that is unlawful, defamatory, obscene, or offensive</li>
            <li>Impersonate any person or entity or misrepresent your affiliation</li>
            <li>Access another user&apos;s account without authorization</li>
            <li>Interfere with or disrupt the App&apos;s services or servers</li>
            <li>Introduce viruses, malware, or other harmful code</li>
            <li>Engage in spamming or send unsolicited communications</li>
            <li>Use the App for any commercial purpose without authorization</li>
            <li>Violate any applicable laws, regulations, or university policies</li>
            <li>Attempt to circumvent any security features of the App</li>
          </ul>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">6. User Content</h2>
          <p className="text-gray-700 leading-relaxed mb-3">
            You are solely responsible for all content you submit, post, or transmit through the App (&quot;User Content&quot;).
            By submitting User Content, you:
          </p>
          <ul className="list-disc pl-6 text-gray-700 space-y-2">
            <li>Grant HallPals a non-exclusive, worldwide, royalty-free license to use, store, display, and
                distribute your User Content solely for the purpose of operating and providing the App</li>
            <li>Represent and warrant that you own or have the necessary rights to submit the User Content</li>
            <li>Represent that your User Content does not violate the rights of any third party</li>
          </ul>
          <p className="text-gray-700 leading-relaxed mt-3">
            We reserve the right to remove any User Content that violates these Terms or that we deem
            inappropriate, without prior notice.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">7. AI Assistant</h2>
          <p className="text-gray-700 leading-relaxed mb-3">
            The App includes an AI assistant feature. By using this feature, you acknowledge and agree that:
          </p>
          <ul className="list-disc pl-6 text-gray-700 space-y-2">
            <li>AI responses are generated automatically and may not always be accurate or complete</li>
            <li>The AI assistant is intended for general information only and is not a substitute for
                professional advice or official university guidance</li>
            <li>You should verify important information with your RA or residence life staff</li>
            <li>You should not share sensitive personal information with the AI assistant</li>
            <li>HallPals is not liable for any actions taken based on AI-generated responses</li>
          </ul>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">8. Privacy</h2>
          <p className="text-gray-700 leading-relaxed">
            Your use of the App is also governed by our <a href="/privacy" className="text-blue-600 hover:underline">Privacy Policy</a>,
            which describes how we collect, use, and protect your information. By using the App, you consent
            to the practices described in the Privacy Policy.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">9. Intellectual Property</h2>
          <p className="text-gray-700 leading-relaxed">
            The App, including its design, features, content, and functionality, is owned by HallPals and
            is protected by copyright, trademark, and other intellectual property laws. You may not copy,
            modify, distribute, sell, lease, or create derivative works based on the App without our
            prior written permission.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">10. Third-Party Services</h2>
          <p className="text-gray-700 leading-relaxed">
            The App may contain links to or integrate with third-party websites, services, or content that
            are not owned or controlled by HallPals. We are not responsible for the content, privacy policies,
            or practices of any third-party services. Your use of third-party services is at your own risk
            and subject to their respective terms and policies.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">11. Disclaimer of Warranties</h2>
          <p className="text-gray-700 leading-relaxed">
            THE APP IS PROVIDED &quot;AS IS&quot; AND &quot;AS AVAILABLE&quot; WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS
            OR IMPLIED, INCLUDING BUT NOT LIMITED TO IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
            PARTICULAR PURPOSE, AND NON-INFRINGEMENT. WE DO NOT WARRANT THAT THE APP WILL BE UNINTERRUPTED,
            ERROR-FREE, OR COMPLETELY SECURE.
          </p>
          <div className="bg-red-50 border-l-4 border-red-500 p-4 mt-4">
            <p className="text-red-800 font-medium">
              IMPORTANT: The App is NOT intended for emergency situations. In case of emergency, immediately
              contact local emergency services (911), campus security, or other appropriate emergency personnel.
            </p>
          </div>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">12. Limitation of Liability</h2>
          <p className="text-gray-700 leading-relaxed">
            TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, HALLPALS AND ITS OFFICERS, DIRECTORS, EMPLOYEES,
            AND AGENTS SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE
            DAMAGES, INCLUDING BUT NOT LIMITED TO LOSS OF PROFITS, DATA, OR GOODWILL, ARISING OUT OF OR
            RELATED TO YOUR USE OF OR INABILITY TO USE THE APP, EVEN IF WE HAVE BEEN ADVISED OF THE
            POSSIBILITY OF SUCH DAMAGES.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">13. Indemnification</h2>
          <p className="text-gray-700 leading-relaxed">
            You agree to indemnify, defend, and hold harmless HallPals and its officers, directors, employees,
            agents, and affiliates from and against any and all claims, damages, losses, liabilities, costs,
            and expenses (including reasonable attorneys&apos; fees) arising out of or related to your use of
            the App, your User Content, or your violation of these Terms.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">14. Termination</h2>
          <p className="text-gray-700 leading-relaxed">
            We may suspend or terminate your access to the App at any time, with or without cause, and with
            or without notice. Upon termination, your right to use the App will immediately cease. You may
            also delete your account at any time through the App settings. Provisions of these Terms that
            by their nature should survive termination shall survive, including ownership provisions,
            warranty disclaimers, and limitations of liability.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">15. Changes to Terms</h2>
          <p className="text-gray-700 leading-relaxed">
            We reserve the right to modify these Terms at any time. When we make changes, we will update
            the &quot;Last Updated&quot; date at the top of this page. Your continued use of the App after any
            changes constitutes your acceptance of the updated Terms. We encourage you to review these
            Terms periodically.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">16. Governing Law</h2>
          <p className="text-gray-700 leading-relaxed">
            These Terms shall be governed by and construed in accordance with the laws of the State of
            Minnesota, United States, without regard to its conflict of law provisions.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">17. Dispute Resolution</h2>
          <p className="text-gray-700 leading-relaxed">
            Any dispute arising out of or relating to these Terms or the App shall be resolved through
            binding arbitration in St. Paul, Minnesota, in accordance with the rules of the American
            Arbitration Association. You agree to waive any right to a jury trial or to participate
            in a class action lawsuit.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">18. Severability</h2>
          <p className="text-gray-700 leading-relaxed">
            If any provision of these Terms is found to be invalid, illegal, or unenforceable, the
            remaining provisions shall continue in full force and effect. The invalid provision shall
            be modified to the minimum extent necessary to make it valid and enforceable.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">19. Entire Agreement</h2>
          <p className="text-gray-700 leading-relaxed">
            These Terms, together with the Privacy Policy, constitute the entire agreement between you
            and HallPals regarding your use of the App and supersede all prior agreements, understandings,
            and communications, whether written or oral.
          </p>
        </section>

        <section className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">20. Contact Us</h2>
          <p className="text-gray-700 leading-relaxed mb-4">
            If you have any questions about these Terms of Service, please contact us:
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
