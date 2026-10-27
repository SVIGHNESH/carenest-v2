import { actionLabel, actorLabel, formatSlot, hourLabel, hoursSummary, isOpen, paymentInfo, rupees, statusInfo } from "./format";

describe("status mapping", () => {
  it("labels every booking status without raw enums", () => {
    for (const s of ["pending_payment", "expired", "confirmed", "in_progress", "completed", "cancelled"]) {
      expect(statusInfo(s).label).not.toContain("_");
    }
    expect(statusInfo("confirmed")).toEqual({ label: "Confirmed", tone: "info" });
    expect(statusInfo("cancelled").tone).toBe("danger");
  });
  it("maps payments, including refund failure as danger", () => {
    expect(paymentInfo("refund_failed").tone).toBe("danger");
    expect(paymentInfo("completed").label).toBe("Paid");
    expect(paymentInfo(null).label).toBe("No payment");
  });
  it("only open bookings can be cancelled", () => {
    expect(isOpen("confirmed")).toBe(true);
    expect(isOpen("in_progress")).toBe(true);
    expect(isOpen("completed")).toBe(false);
    expect(isOpen("cancelled")).toBe(false);
  });
});

describe("formatting", () => {
  it("formats hours and money", () => {
    expect(hourLabel(0)).toBe("12:00 AM");
    expect(hourLabel(12)).toBe("12:00 PM");
    expect(hourLabel(15)).toBe("3:00 PM");
    expect(hourLabel(24)).toBe("12:00 AM");
    expect(rupees(1600)).toBe("Rs 1,600");
  });
  it("formats a slot from a naive IST string without shifting zones", () => {
    expect(formatSlot("2026-10-10T15:00:00", 4)).toContain("3:00 PM, 4 hours");
    expect(formatSlot("2026-10-10T15:00:00", 1)).toContain("1 hour");
  });
  it("summarises weekly hours", () => {
    expect(hoursSummary([])).toBe("Not set");
    const mon_sat = [0, 1, 2, 3, 4, 5].map((weekday) => ({ weekday, start_hour: 8, end_hour: 20 }));
    expect(hoursSummary(mon_sat)).toBe("Mon to Sat, 8:00 AM to 8:00 PM");
  });
  it("describes history entries", () => {
    expect(actionLabel("booking_confirmed")).toContain("confirmed");
    expect(actionLabel("some_new_thing")).toBe("some new thing");
    expect(actorLabel("system")).toBe("automatic");
    expect(actorLabel("admin:3 Priya")).toBe("Priya");
  });
});
