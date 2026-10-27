import { Card, PageHeader } from "@/components/ui";

const GUIDES: { q: string; a: string[] }[] = [
  {
    q: "How do I cancel a booking?",
    a: ["Open the booking and press Cancel booking. It works on any booking that is not completed or cancelled, even a visit that has started.", "Type a reason (up to 40 characters). The user sees it in an SMS.", "If the user paid, the full refund is sent automatically. If the refund call fails, the booking is still cancelled and the refund shows under Needs attention for you to do by hand."],
  },
  {
    q: "How do I swap the nurse on a booking?",
    a: ["Open the booking and press Reassign nurse. Free nurses are listed, qualified and same-gender first.", "The old nurse is told the visit is removed, the new nurse gets the details, and the user is told the new name."],
  },
  {
    q: "How do I set a nurse on leave?",
    a: ["Nurses > Availability on that nurse, then click the day in the calendar.", "If the day already has bookings, use Bookings > Nurse unavailable. It moves each booking to another nurse where it can, and cancels with a refund where it cannot."],
  },
  {
    q: "What does \"Needs attention\" mean?",
    a: ["Failed refunds, bookings the system cancelled because no nurse was free after payment, nurse messages that did not go through, and nurses who cannot be booked yet because hours or services are missing."],
  },
  {
    q: "A nurse says the SMS never arrived",
    a: ["Open the booking, find the message under Messages and press Resend. You can also read the visit details out over the phone from the booking page."],
  },
  {
    q: "Who do I contact for help?",
    a: ["Contact the CareNest development team using the details given at handover."],
  },
];

export function HelpPage() {
  return (
    <>
      <PageHeader title="Help" description="Short guides for day-to-day work." />
      <div className="grid max-w-3xl gap-3">
        {GUIDES.map((g) => (
          <Card key={g.q}>
            <details className="group">
              <summary className="cursor-pointer list-none px-4 py-3 text-base font-medium marker:hidden">{g.q}</summary>
              <div className="space-y-2 border-t border-border px-4 py-3 text-sm text-fg-secondary">
                {g.a.map((p) => (
                  <p key={p}>{p}</p>
                ))}
              </div>
            </details>
          </Card>
        ))}
      </div>
    </>
  );
}
