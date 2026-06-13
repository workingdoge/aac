// A single step in the five-step flow. Presentational only.

export interface StepAction {
  label: string;
  onClick: () => void | Promise<void>;
  busy: boolean;
  disabled: boolean;
}

export function StepCard(props: {
  n: number;
  title: string;
  detail: string;
  done: boolean;
  action: StepAction;
}) {
  const { n, title, detail, done, action } = props;
  return (
    <section
      style={{
        border: "1px solid #e2e2e2",
        borderRadius: 8,
        padding: 12,
        marginBottom: 10,
        opacity: action.disabled && !done ? 0.55 : 1,
      }}
    >
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <strong style={{ fontSize: 14 }}>
          {done ? "✓" : n}. {title}
        </strong>
        <button
          onClick={() => void action.onClick()}
          disabled={action.disabled || action.busy}
          style={{
            fontSize: 12,
            padding: "4px 10px",
            borderRadius: 6,
            border: "1px solid #ccc",
            cursor: action.disabled ? "not-allowed" : "pointer",
          }}
        >
          {action.busy ? "…" : action.label}
        </button>
      </div>
      <div style={{ color: "#666", fontSize: 12, marginTop: 6 }}>{detail}</div>
    </section>
  );
}
