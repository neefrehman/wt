import { Children, createContext, isValidElement, use, useState } from "react";

import { StatusMessage } from "@inkjs/ui";
import { Box, Text, useInput } from "ink";

import { createFormHook, createFormHookContexts } from "@tanstack/react-form";
import * as R from "remeda";
import { match } from "ts-pattern";

import { Select } from "#/components/Select.js";

const { fieldContext, formContext, useFieldContext, useFormContext } = createFormHookContexts();

type StepStatus = "future" | "active" | "complete" | "cancelled";

interface WizardProps {
  children: React.ReactNode;
  onCancel?: () => void;
}

const Wizard = ({ children, onCancel }: WizardProps) => {
  const [currentStep, setCurrentStep] = useState(0);
  const [cancelledAt, setCancelledAt] = useState<number | null>(null);

  const form = useFormContext();

  const [steps, postCompleteSteps] = R.partition(
    Children.toArray(children),
    (child) => isValidElement<{ name?: string }>(child) && !!child.props.name,
  );

  const advance = () => {
    if (!form.state.isValid) {
      setCancelledAt(currentStep);
      return onCancel?.();
    }
    setCurrentStep((prev) => {
      const next = prev + 1;
      if (next >= steps.length && cancelledAt === null) {
        void form.handleSubmit();
      }
      return next;
    });
  };

  useInput((_, key) => {
    if (cancelledAt === null && currentStep < steps.length && key.escape) {
      setCancelledAt(currentStep);
      onCancel?.();
    }
  });

  const getStepStatus = (index: number): StepStatus => {
    const pivot = cancelledAt ?? currentStep;
    if (index < pivot) {
      return "complete";
    }
    if (index === pivot) {
      return cancelledAt !== null ? "cancelled" : "active";
    }
    return "future";
  };

  const isComplete = currentStep >= steps.length && cancelledAt === null;

  return (
    <Box flexDirection="column" gap={1}>
      <Box flexDirection="column">
        {steps.map((child, index) => {
          if (!isValidElement<{ name?: string }>(child)) {
            throw new Error("Expected all children to be valid elements");
          }
          return (
            <StepContext.Provider
              key={child.props.name ?? index}
              value={{ advance, index, status: getStepStatus(index) }}
            >
              {child}
            </StepContext.Provider>
          );
        })}
      </Box>
      {isComplete && postCompleteSteps}
    </Box>
  );
};

interface StepContextValue {
  advance?: () => void;
  index?: number;
  status: StepStatus;
}

const StepContext = createContext<StepContextValue>({ status: "future" });

interface StepProps {
  children: React.ReactNode;
  title: string;
}

const WizardStep = ({ children, title }: StepProps) => {
  const { index, status } = use(StepContext);
  const { state } = useFieldContext<string | string[]>();
  const { meta, value } = state;

  return match(status)
    .with("future", () => null)
    .with("cancelled", () => (
      <StatusMessage variant="error">
        <Text dimColor>{title}:</Text>{" "}
        <Text color="red">{meta.errors[0]?.message ?? "cancelled"}</Text>
      </StatusMessage>
    ))
    .with("complete", () => (
      <StatusMessage variant="success">
        <Text dimColor>{title}:</Text>{" "}
        <Text color="cyan">{Array.isArray(value) ? value.join(", ") : value}</Text>
      </StatusMessage>
    ))
    .with("active", () => (
      <Box flexDirection="column" paddingTop={index === 0 ? 0 : 1} gap={1}>
        <Text bold>{title}</Text>
        {children}
      </Box>
    ))
    .exhaustive();
};

const PostCompletionStep = ({ children }: { children: React.ReactNode }) => (
  <StatusMessage variant="success">{children}</StatusMessage>
);

export const { useAppForm: useWizardForm } = createFormHook({
  formContext,
  fieldContext,
  formComponents: { Wizard, PostCompletionStep },
  fieldComponents: {
    WizardStep,
    Select: Object.assign((props: React.ComponentProps<typeof Select>) => {
      const field = useFieldContext<string | string[]>();
      const { advance } = use(StepContext);
      return (
        <Select
          defaultValue={field.state.value}
          onSubmit={(value) => {
            field.setValue(value);
            advance?.();
          }}
          {...props}
        />
      );
    }, Select),
  },
});
