'use client';

import clsx from 'clsx';

interface TextBlockProps {
  content: string;
  isRotated?: boolean;
  isTight?: boolean;
  isUppercase?: boolean;
  className?: string;
}

export default function TextBlock({
  content,
  isRotated = false,
  isTight = false,
  isUppercase = false,
  className,
}: TextBlockProps) {
  return (
    <p
      className={clsx(
        'text-base font-bold leading-relaxed',
        isRotated && 'text-rotated',
        isTight && 'text-tight',
        isUppercase && 'uppercase',
        className
      )}
    >
      {content}
    </p>
  );
}
