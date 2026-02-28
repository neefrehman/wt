import {
  Children,
  createContext,
  isValidElement,
  use,
  useEffect,
  useEffectEvent,
  useState,
} from "react";

import { TextInput } from "@inkjs/ui";
import { Box, Text, useInput } from "ink";

import figures from "figures";
import * as R from "remeda";

interface Item {
  disabled: boolean;
  kind: "option" | "textInput";
  value: string;
}

interface ItemContextValue {
  isFocused: boolean;
  isSelected: boolean;
  isTyping: boolean;
  onSubmitValue: (value: string) => void;
  onTypingChange: (typing: boolean) => void;
  selectionMode: "single" | "multiple";
}

const ItemContext = createContext<ItemContextValue>({
  isFocused: false,
  isSelected: false,
  isTyping: false,
  onSubmitValue: R.doNothing,
  onTypingChange: R.doNothing,
  selectionMode: "single",
});

function findFocusable(items: Item[], from: number, direction: 1 | -1): number {
  let idx = from + direction;
  while (idx >= 0 && idx < items.length) {
    const item = items[idx];
    if (item && !item.disabled) {
      return idx;
    }
    idx += direction;
  }
  return from;
}

function firstFocusable(items: Item[], preferIndex: number): number {
  const preferred = items[preferIndex];
  if (preferred && !preferred.disabled) {
    return preferIndex;
  }
  return Math.max(0, findFocusable(items, -1, 1));
}

function defaultFocusIndex(items: Item[], defaultValue?: string | string[]) {
  const target = Array.isArray(defaultValue) ? defaultValue[0] : defaultValue;
  const idx = target ? items.findIndex((it) => it.value === target) : -1;
  return firstFocusable(items, idx);
}

function defaultSelectedValues(defaultValue?: string | string[]) {
  return new Set(Array.isArray(defaultValue) ? defaultValue : []);
}

interface SelectOptionProps {
  children: React.ReactNode;
  disabled?: boolean;
  value: string;
}

function SelectOption({ children, disabled }: SelectOptionProps) {
  const { selectionMode, isFocused, isSelected } = use(ItemContext);

  if (disabled) {
    return (
      <Box paddingLeft={2}>
        <Text dimColor>
          {figures.cross} {children}
        </Text>
      </Box>
    );
  }

  if (selectionMode === "multiple") {
    const indicator = isSelected ? (
      <Text color="green">{figures.tick}</Text>
    ) : (
      <Text dimColor>{figures.circle}</Text>
    );

    return (
      <Box paddingLeft={isFocused ? 0 : 2}>
        {isFocused && <Text color="blue">{figures.pointer} </Text>}
        {indicator}
        <Text color={isFocused ? "blue" : undefined}> {children}</Text>
      </Box>
    );
  }

  return (
    <Box paddingLeft={isFocused ? 0 : 2}>
      {isFocused && <Text color="blue">{figures.pointer} </Text>}
      <Text color={isFocused ? "blue" : undefined}>{children}</Text>
    </Box>
  );
}

interface SelectTextInputProps {
  placeholder?: string;
}

function SelectTextInput({ placeholder = "Type something…" }: SelectTextInputProps) {
  const { isFocused, isTyping, onTypingChange, onSubmitValue } = use(ItemContext);

  if (isFocused) {
    return (
      <Box paddingLeft={0}>
        <Text color="blue">
          {figures.pointer}{" "}
          <TextInput
            placeholder={placeholder}
            onSubmit={(value) => {
              onSubmitValue(value);
            }}
            onChange={() => {
              if (!isTyping) {
                onTypingChange(true);
              }
            }}
          />
        </Text>
      </Box>
    );
  }

  return (
    <Box paddingLeft={2}>
      <Text dimColor>{placeholder}</Text>
    </Box>
  );
}

interface SelectProps {
  children: React.ReactNode;
  defaultValue?: string | string[];
  onChange?: (value: string | string[]) => void;
  onSubmit?: (value: string | string[]) => void;
  selectionMode?: "single" | "multiple";
}

function Select({
  selectionMode = "single",
  defaultValue,
  onChange,
  onSubmit,
  children,
}: SelectProps) {
  const items = R.pipe(
    Children.toArray(children),
    R.filter(isValidElement),
    R.flatMap((child): Item[] => {
      if (child.type === SelectOption) {
        const props = child.props as SelectOptionProps;
        return [{ value: props.value, disabled: !!props.disabled, kind: "option" }];
      }
      if (child.type === SelectTextInput) {
        return [{ value: "__textInput__", disabled: false, kind: "textInput" }];
      }
      return [];
    }),
  );

  const [focusIndex, setFocusIndex] = useState(() => defaultFocusIndex(items, defaultValue));
  const [selected, setSelected] = useState(() => defaultSelectedValues(defaultValue));
  const [isTyping, setIsTyping] = useState(false);

  // Reset if conditional rendering changes items
  const itemKey = items.map((i) => i.value).join(",");
  const reset = useEffectEvent(() => {
    setFocusIndex(defaultFocusIndex(items, defaultValue));
    setSelected(defaultSelectedValues(defaultValue));
  });
  // biome-ignore lint/correctness/useExhaustiveDependencies: biome doesn't understand useEffectEvent
  useEffect(reset, [itemKey]);

  const toggleValue = (value: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(value)) {
        next.delete(value);
      } else {
        next.add(value);
      }
      return next;
    });
  };

  useInput((input, key) => {
    // Arrows always work — even while typing — so you can navigate back
    if (key.upArrow || key.downArrow) {
      setIsTyping(false);
      setFocusIndex((i) => findFocusable(items, i, key.upArrow ? -1 : 1));
      return;
    }

    // All other keys are swallowed while typing (TextInput handles them)
    if (isTyping) {
      return;
    }

    const focusedItem = items[focusIndex];

    if (key.return) {
      if (selectionMode === "multiple") {
        onSubmit?.([...selected]);
      } else {
        onSubmit?.(focusedItem?.value ?? "");
      }
      return;
    }

    if (selectionMode === "multiple" && input === " ") {
      if (focusedItem && !focusedItem.disabled) {
        toggleValue(focusedItem.value);
        const next = new Set(selected);
        if (next.has(focusedItem.value)) {
          next.delete(focusedItem.value);
        } else {
          next.add(focusedItem.value);
        }
        onChange?.([...next]);
      }
      return;
    }

    if (selectionMode === "multiple" && input === "a") {
      const allNonDisabled = items
        .filter((i) => !i.disabled && i.kind === "option")
        .map((i) => i.value);
      const allSelected = allNonDisabled.every((v) => selected.has(v));
      if (allSelected) {
        setSelected(new Set());
        onChange?.([]);
      } else {
        setSelected(new Set(allNonDisabled));
        onChange?.(allNonDisabled);
      }
      return;
    }

    if (focusedItem?.kind === "textInput" && input.length > 0 && !key.return) {
      setIsTyping(true);
    }
  });

  const rendered = Children.toArray(children)
    .filter(isValidElement)
    .filter((c) => c.type === SelectOption || c.type === SelectTextInput)
    .map((child, i) => (
      <ItemContext
        key={child.key ?? i}
        value={{
          isFocused: focusIndex === i,
          isSelected: selected.has(items[i]?.value ?? ""),
          isTyping,
          onSubmitValue: (value: string) => onSubmit?.(value),
          onTypingChange: setIsTyping,
          selectionMode,
        }}
      >
        {child}
      </ItemContext>
    ));

  const hintText =
    selectionMode === "multiple"
      ? "↑↓ navigate · space select · a all · enter confirm"
      : "↑↓ navigate · enter select";

  return (
    <Box flexDirection="column" gap={1}>
      <Box flexDirection="column">{rendered}</Box>
      <Text dimColor>{hintText}</Text>
    </Box>
  );
}

Select.Option = SelectOption;
Select.TextInput = SelectTextInput;

export { Select };
export type { SelectProps, SelectOptionProps, SelectTextInputProps };
