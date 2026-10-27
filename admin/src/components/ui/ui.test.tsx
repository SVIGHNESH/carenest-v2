import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { vi } from "vitest";
import { CancelDialog } from "@/pages/BookingDetail";
import type { Schemas } from "@/api/client";
import { Badge, Button, Field } from "./index";

const booking = {
  id: 1042,
  status: "confirmed",
  patient_name: "R. Sharma",
  slot_start: "2026-10-10T15:00:00",
  hours: 4,
  amount: 1600,
  nurse: { id: 1, name: "Anita S.", phone: "+919000000001", gender: "female" },
  payment: { status: "completed", amount: 1600 },
} as unknown as Schemas["AdminBookingDetail"];

const wrap = (ui: React.ReactElement) => render(<QueryClientProvider client={new QueryClient()}>{ui}</QueryClientProvider>);

describe("Cancel dialog (kill switch)", () => {
  it("shows the refund and keeps the confirm button disabled until a reason is typed", async () => {
    const user = userEvent.setup();
    wrap(<CancelDialog b={booking} onClose={vi.fn()} onDone={vi.fn()} />);
    expect(screen.getByText("Rs 1,600 (full)")).toBeInTheDocument();
    const confirm = screen.getByRole("button", { name: "Cancel booking and refund" });
    expect(confirm).toBeDisabled();
    await user.type(screen.getByLabelText(/Reason/), "nurse unwell");
    expect(confirm).toBeEnabled();
  });
  it("does not promise a refund for an unpaid booking", () => {
    const unpaid = { ...booking, payment: null } as unknown as Schemas["AdminBookingDetail"];
    wrap(<CancelDialog b={unpaid} onClose={vi.fn()} onDone={vi.fn()} />);
    expect(screen.getByText("Nothing paid")).toBeInTheDocument();
    expect(screen.queryByText(/refund is sent/i)).not.toBeInTheDocument();
  });
});

describe("primitives", () => {
  it("shows a field error as an alert", () => {
    render(
      <Field label="Email" error="Enter a valid email">
        <input />
      </Field>,
    );
    expect(screen.getByRole("alert")).toHaveTextContent("Enter a valid email");
  });
  it("disables a loading button", () => {
    render(<Button loading>Save</Button>);
    expect(screen.getByRole("button")).toBeDisabled();
  });
  it("renders a badge label", () => {
    render(<Badge tone="success">Paid</Badge>);
    expect(screen.getByText("Paid")).toBeInTheDocument();
  });
});
