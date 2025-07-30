import React from 'react';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { cn } from '@/lib/utils';

interface FormInputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: string;
  icon?: React.ReactNode;
}

export const FormInput: React.FC<FormInputProps> = ({
  label,
  error,
  icon,
  className,
  ...props
}) => {
  return (
    <div className="space-y-2">
      <Label htmlFor={props.id} className="flex items-center">
        {icon && <span className="mr-2">{icon}</span>}
        {label}
        {props.required && <span className="text-destructive ml-1">*</span>}
      </Label>
      <div className="relative">
        {icon && (
          <div className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground">
            {icon}
          </div>
        )}
        <Input
          {...props}
          className={cn(
            icon ? 'pl-10' : '',
            error ? 'border-destructive' : '',
            className
          )}
        />
      </div>
      {error && (
        <p className="text-sm text-destructive">{error}</p>
      )}
    </div>
  );
};

interface FormTextareaProps extends React.TextareaHTMLAttributes<HTMLTextAreaElement> {
  label: string;
  error?: string;
  icon?: React.ReactNode;
}

export const FormTextarea: React.FC<FormTextareaProps> = ({
  label,
  error,
  icon,
  className,
  ...props
}) => {
  return (
    <div className="space-y-2">
      <Label htmlFor={props.id} className="flex items-center">
        {icon && <span className="mr-2">{icon}</span>}
        {label}
        {props.required && <span className="text-destructive ml-1">*</span>}
      </Label>
      <Textarea
        {...props}
        className={cn(
          error ? 'border-destructive' : '',
          className
        )}
      />
      {error && (
        <p className="text-sm text-destructive">{error}</p>
      )}
    </div>
  );
};

interface FormSelectProps {
  label: string;
  error?: string;
  icon?: React.ReactNode;
  children: React.ReactNode;
}

export const FormSelect: React.FC<FormSelectProps> = ({
  label,
  error,
  icon,
  children
}) => {
  return (
    <div className="space-y-2">
      <Label className="flex items-center">
        {icon && <span className="mr-2">{icon}</span>}
        {label}
      </Label>
      {children}
      {error && (
        <p className="text-sm text-destructive">{error}</p>
      )}
    </div>
  );
};