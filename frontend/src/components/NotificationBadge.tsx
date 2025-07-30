import React from 'react';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

interface NotificationBadgeProps {
  count: number;
  className?: string;
  variant?: 'default' | 'destructive' | 'outline' | 'secondary';
  showZero?: boolean;
}

export const NotificationBadge: React.FC<NotificationBadgeProps> = ({ 
  count, 
  className,
  variant = 'destructive',
  showZero = false 
}) => {
  if (count === 0 && !showZero) {
    return null;
  }

  const displayCount = count > 99 ? '99+' : count.toString();

  return (
    <Badge 
      variant={variant}
      className={cn(
        'text-xs px-1.5 py-0.5 min-w-[1.2rem] h-5 flex items-center justify-center',
        className
      )}
    >
      {displayCount}
    </Badge>
  );
};