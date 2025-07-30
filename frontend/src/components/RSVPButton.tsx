import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Check, X, Loader2 } from 'lucide-react';
import { api } from '@/lib/api';
import { useToast } from '@/hooks/use-toast';

interface RSVPButtonProps {
  eventId: number;
  isAttending: boolean;
  onStatusChange?: (isAttending: boolean) => void;
  size?: 'sm' | 'default' | 'lg';
}

export const RSVPButton: React.FC<RSVPButtonProps> = ({ 
  eventId, 
  isAttending: initialAttending, 
  onStatusChange,
  size = 'default'
}) => {
  const [isAttending, setIsAttending] = useState(initialAttending);
  const [loading, setLoading] = useState(false);
  const { toast } = useToast();

  const handleRSVP = async () => {
    setLoading(true);
    
    try {
      if (isAttending) {
        await api.delete(`/api/events/${eventId}/rsvp`);
        setIsAttending(false);
        onStatusChange?.(false);
        toast({
          title: "RSVP Removed",
          description: "You are no longer attending this event.",
        });
      } else {
        await api.post(`/api/events/${eventId}/rsvp`);
        setIsAttending(true);
        onStatusChange?.(true);
        toast({
          title: "RSVP Confirmed",
          description: "You are now attending this event!",
        });
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to update RSVP. Please try again.",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <Button disabled size={size} variant="outline">
        <Loader2 className="h-4 w-4 animate-spin mr-2" />
        Updating...
      </Button>
    );
  }

  if (isAttending) {
    return (
      <Button 
        onClick={handleRSVP}
        size={size}
        variant="default"
        className="bg-success hover:bg-success/90"
      >
        <Check className="h-4 w-4 mr-2" />
        Attending
      </Button>
    );
  }

  return (
    <Button 
      onClick={handleRSVP}
      size={size}
      variant="outline"
      className="hover:bg-primary hover:text-primary-foreground"
    >
      RSVP
    </Button>
  );
};