import React, { useState, useEffect } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { Event } from '@/types/event';
import { useAuth } from '@/contexts/AuthContext';
import { RSVPButton } from '@/components/RSVPButton';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Separator } from '@/components/ui/separator';
import { 
  Calendar, 
  MapPin, 
  Users, 
  Clock, 
  Edit, 
  Share2, 
  Lock,
  ArrowLeft,
  UserPlus,
  MessageCircle
} from 'lucide-react';
import { format } from 'date-fns';
import { api } from '@/lib/api';
import { useToast } from '@/hooks/use-toast';

interface Attendee {
  id: number;
  name: string;
  email: string;
  avatar_url?: string;
  status: 'attending' | 'maybe' | 'not_attending';
}

export const EventDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const { user, isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const { toast } = useToast();
  
  const [event, setEvent] = useState<Event | null>(null);
  const [attendees, setAttendees] = useState<Attendee[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (id) {
      fetchEventDetails();
    }
  }, [id]);

  const fetchEventDetails = async () => {
    try {
      setLoading(true);
      const [eventResponse, attendeesResponse] = await Promise.all([
        api.get(`/api/events/${id}`),
        api.get(`/api/events/${id}/attendees`)
      ]);
      
      setEvent(eventResponse.event || eventResponse);
      setAttendees(attendeesResponse.attendees || attendeesResponse);
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to load event details. Please try again.",
        variant: "destructive",
      });
      navigate('/');
    } finally {
      setLoading(false);
    }
  };

  const handleRSVPChange = (isAttending: boolean) => {
    if (event) {
      setEvent({
        ...event,
        is_attending: isAttending,
        attendees_count: isAttending ? event.attendees_count + 1 : event.attendees_count - 1
      });
      
      // Refresh attendees list
      fetchEventDetails();
    }
  };

  const handleShare = async () => {
    try {
      await navigator.share({
        title: event?.name,
        text: event?.description,
        url: window.location.href,
      });
    } catch (error) {
      // Fallback: copy to clipboard
      navigator.clipboard.writeText(window.location.href);
      toast({
        title: "Link copied!",
        description: "Event link has been copied to clipboard.",
      });
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4"></div>
          <p className="text-muted-foreground">Loading event details...</p>
        </div>
      </div>
    );
  }

  if (!event) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <h2 className="text-2xl font-bold text-foreground mb-2">Event not found</h2>
          <p className="text-muted-foreground mb-4">The event you're looking for doesn't exist.</p>
          <Link to="/">
            <Button>Back to Events</Button>
          </Link>
        </div>
      </div>
    );
  }

  const isEventCreator = user?.id === event.creator_id;
  const isUpcoming = new Date(event.date) > new Date();
  const eventDate = new Date(event.date);
  const endDate = null; // No end date in new schema

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Back Button */}
        <Button variant="ghost" onClick={() => navigate(-1)} className="mb-6">
          <ArrowLeft className="h-4 w-4 mr-2" />
          Back
        </Button>

        {/* Event Header */}
        <Card className="mb-8">
          <CardHeader className="pb-4">
            <div className="flex flex-col md:flex-row md:items-start md:justify-between gap-4">
              <div className="flex-1">
                <div className="flex items-center space-x-2 mb-3">
                  <h1 className="text-3xl font-bold text-foreground">{event.name}</h1>
                  {event.private && (
                    <Badge variant="secondary" className="flex items-center space-x-1">
                      <Lock className="h-3 w-3" />
                      <span>Private</span>
                    </Badge>
                  )}
                  {!isUpcoming && (
                    <Badge variant="outline">Past Event</Badge>
                  )}
                </div>
                
                <div className="flex items-center space-x-2 mb-4">
                  <Avatar className="h-8 w-8">
                    <AvatarFallback>
                      {event.creator.email.charAt(0).toUpperCase()}
                    </AvatarFallback>
                  </Avatar>
                  <span className="text-muted-foreground">
                    Organized by <span className="font-medium text-foreground">{event.creator.email}</span>
                  </span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
                  <div className="flex items-center text-muted-foreground">
                    <Calendar className="h-4 w-4 mr-2" />
                    <div>
                      <div>{format(eventDate, 'EEEE, MMMM d, yyyy')}</div>
                      <div className="text-xs">{format(eventDate, 'h:mm a')} {endDate && `- ${format(endDate, 'h:mm a')}`}</div>
                    </div>
                  </div>
                  
                  <div className="flex items-center text-muted-foreground">
                    <MapPin className="h-4 w-4 mr-2" />
                    <span>{event.location}</span>
                  </div>
                  
                  <div className="flex items-center text-muted-foreground">
                    <Users className="h-4 w-4 mr-2" />
                    <span>
                      {event.attendees_count} {event.attendees_count === 1 ? 'attendee' : 'attendees'}
                    </span>
                  </div>
                  
                  <div className="flex items-center text-muted-foreground">
                    <Clock className="h-4 w-4 mr-2" />
                    <span>Created {format(new Date(event.created_at), 'MMM d, yyyy')}</span>
                  </div>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex flex-col space-y-2 md:w-auto w-full">
                {isAuthenticated && isUpcoming && !isEventCreator && (
                  <RSVPButton 
                    eventId={event.id} 
                    isAttending={event.is_attending}
                    onStatusChange={handleRSVPChange}
                    size="lg"
                  />
                )}
                
                {isEventCreator && (
                  <div className="flex space-x-2">
                    <Link to={`/events/${event.id}/edit`}>
                      <Button variant="outline" size="lg">
                        <Edit className="h-4 w-4 mr-2" />
                        Edit
                      </Button>
                    </Link>
                    <Link to={`/events/${event.id}/invite`}>
                      <Button variant="outline" size="lg">
                        <UserPlus className="h-4 w-4 mr-2" />
                        Invite
                      </Button>
                    </Link>
                  </div>
                )}
                
                <Button variant="outline" onClick={handleShare} size="lg">
                  <Share2 className="h-4 w-4 mr-2" />
                  Share
                </Button>
              </div>
            </div>
          </CardHeader>
        </Card>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Main Content */}
          <div className="lg:col-span-2 space-y-6">
            {/* Description */}
            <Card>
              <CardHeader>
                <CardTitle>About this event</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="prose prose-sm max-w-none">
                  <p className="text-muted-foreground whitespace-pre-wrap">{event.description}</p>
                </div>
              </CardContent>
            </Card>

            {/* Event Discussion (Placeholder) */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center">
                  <MessageCircle className="h-5 w-5 mr-2" />
                  Discussion
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-center py-8 text-muted-foreground">
                  <MessageCircle className="h-12 w-12 mx-auto mb-4 opacity-50" />
                  <p>Event discussion coming soon...</p>
                  <p className="text-sm">Connect with other attendees and ask questions about the event.</p>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* Attendees */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center justify-between">
                  <span>Attendees ({attendees.length})</span>
                  <Users className="h-5 w-5" />
                </CardTitle>
              </CardHeader>
              <CardContent>
                {attendees.length > 0 ? (
                  <div className="space-y-3">
                    {attendees.slice(0, 10).map((attendee) => (
                      <div key={attendee.id} className="flex items-center space-x-3">
                        <Avatar className="h-8 w-8">
                          <AvatarImage src={attendee.avatar_url} alt={attendee.name} />
                          <AvatarFallback>
                            {attendee.name.charAt(0).toUpperCase()}
                          </AvatarFallback>
                        </Avatar>
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-medium text-foreground truncate">
                            {attendee.name}
                          </p>
                          <p className="text-xs text-muted-foreground truncate">
                            {attendee.email}
                          </p>
                        </div>
                        {attendee.status === 'attending' && (
                          <Badge variant="secondary" className="text-xs">
                            Going
                          </Badge>
                        )}
                      </div>
                    ))}
                    
                    {attendees.length > 10 && (
                      <div className="text-center pt-2">
                        <Button variant="ghost" size="sm">
                          View all {attendees.length} attendees
                        </Button>
                      </div>
                    )}
                  </div>
                ) : (
                  <div className="text-center py-6 text-muted-foreground">
                    <Users className="h-8 w-8 mx-auto mb-2 opacity-50" />
                    <p className="text-sm">No attendees yet</p>
                    {isUpcoming && (
                      <p className="text-xs">Be the first to RSVP!</p>
                    )}
                  </div>
                )}
              </CardContent>
            </Card>

            {/* Event Details */}
            <Card>
              <CardHeader>
                <CardTitle>Event Details</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                  <div>
                    <h4 className="text-sm font-medium text-foreground mb-1">Visibility</h4>
                    <div className="flex items-center space-x-2">
                      {event.private ? (
                        <>
                          <Lock className="h-4 w-4 text-muted-foreground" />
                          <span className="text-sm text-muted-foreground">Private Event</span>
                        </>
                      ) : (
                        <>
                          <Users className="h-4 w-4 text-muted-foreground" />
                          <span className="text-sm text-muted-foreground">Public Event</span>
                        </>
                      )}
                    </div>
                  </div>
                
                <Separator />
                
                <div>
                  <h4 className="text-sm font-medium text-foreground mb-1">Created</h4>
                  <p className="text-sm text-muted-foreground">
                    {format(new Date(event.created_at), 'MMMM d, yyyy')}
                  </p>
                </div>
                
                {event.updated_at !== event.created_at && (
                  <>
                    <Separator />
                    <div>
                      <h4 className="text-sm font-medium text-foreground mb-1">Last Updated</h4>
                      <p className="text-sm text-muted-foreground">
                        {format(new Date(event.updated_at), 'MMMM d, yyyy')}
                      </p>
                    </div>
                  </>
                )}
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </div>
  );
};