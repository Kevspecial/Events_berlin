import React from 'react';
import { Link } from 'react-router-dom';
import { Event } from '@/types/event';
import { Card, CardContent, CardFooter, CardHeader } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Calendar, MapPin, Users, Clock, Lock } from 'lucide-react';
import { format } from 'date-fns';
import { RSVPButton } from './RSVPButton';
import { useAuth } from '@/contexts/AuthContext';

interface EventCardProps {
  event: Event;
  variant?: 'default' | 'compact';
  showRSVP?: boolean;
}

export const EventCard: React.FC<EventCardProps> = ({ 
  event, 
  variant = 'default',
  showRSVP = true 
}) => {
  const { isAuthenticated } = useAuth();
  
  const formatEventDate = (dateString: string) => {
    return format(new Date(dateString), 'MMM d, yyyy');
  };

  const formatEventTime = (dateString: string) => {
    return format(new Date(dateString), 'h:mm a');
  };

  const isUpcoming = new Date(event.date) > new Date();

  if (variant === 'compact') {
    return (
      <Card className="hover:shadow-md transition-shadow">
        <CardContent className="p-4">
          <div className="flex items-start justify-between">
            <div className="flex-1 min-w-0">
              <div className="flex items-center space-x-2 mb-2">
                <Link to={`/events/${event.id}`}>
                  <h3 className="font-semibold text-foreground hover:text-primary transition-colors truncate">
                    {event.name}
                  </h3>
                </Link>
                {event.private && (
                  <Lock className="h-4 w-4 text-muted-foreground" />
                )}
              </div>
              
              <div className="flex items-center text-sm text-muted-foreground space-x-4">
                <div className="flex items-center">
                  <Calendar className="h-4 w-4 mr-1" />
                  {formatEventDate(event.date)}
                </div>
                <div className="flex items-center">
                  <Clock className="h-4 w-4 mr-1" />
                  {formatEventTime(event.date)}
                </div>
              </div>
            </div>
            
            {showRSVP && isAuthenticated && isUpcoming && (
              <RSVPButton 
                eventId={event.id} 
                isAttending={event.is_attending}
                size="sm"
              />
            )}
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="hover:shadow-lg transition-all duration-300 group">
      <CardHeader className="pb-3">
        <div className="flex items-start justify-between">
          <div className="flex-1 min-w-0">
            <div className="flex items-center space-x-2 mb-2">
              <Link to={`/events/${event.id}`}>
                <h3 className="text-xl font-semibold text-foreground group-hover:text-primary transition-colors">
                  {event.name}
                </h3>
              </Link>
              {event.private && (
                <Badge variant="secondary" className="flex items-center space-x-1">
                  <Lock className="h-3 w-3" />
                  <span>Private</span>
                </Badge>
              )}
            </div>
            
            <div className="flex items-center space-x-2">
              <Avatar className="h-6 w-6">
                <AvatarFallback>
                  {event.creator.email.charAt(0).toUpperCase()}
                </AvatarFallback>
              </Avatar>
              <span className="text-sm text-muted-foreground">
                by {event.creator.email}
              </span>
            </div>
          </div>
          
          {!isUpcoming && (
            <Badge variant="outline">Past Event</Badge>
          )}
        </div>
      </CardHeader>

      <CardContent className="pb-4">
        <p className="text-muted-foreground mb-4 line-clamp-2">
          {event.description}
        </p>
        
        <div className="space-y-2">
          <div className="flex items-center text-sm text-muted-foreground">
            <Calendar className="h-4 w-4 mr-2" />
            <span>
              {formatEventDate(event.date)} at {formatEventTime(event.date)}
            </span>
          </div>
          
          <div className="flex items-center text-sm text-muted-foreground">
            <MapPin className="h-4 w-4 mr-2" />
            <span className="truncate">{event.location}</span>
          </div>
          
          <div className="flex items-center text-sm text-muted-foreground">
            <Users className="h-4 w-4 mr-2" />
            <span>
              {event.attendees_count} {event.attendees_count === 1 ? 'attendee' : 'attendees'}
            </span>
          </div>
        </div>
      </CardContent>

      <CardFooter className="pt-0">
        <div className="flex items-center justify-between w-full">
          <Link to={`/events/${event.id}`}>
            <Button variant="outline" size="sm">
              View Details
            </Button>
          </Link>
          
          {showRSVP && isAuthenticated && isUpcoming && (
            <RSVPButton 
              eventId={event.id} 
              isAttending={event.is_attending}
            />
          )}
        </div>
      </CardFooter>
    </Card>
  );
};