import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { Event, Invitation } from '@/types/event';
import { EventCard } from '@/components/EventCard';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { 
  Calendar, 
  Plus, 
  Users, 
  Clock, 
  TrendingUp, 
  Mail,
  Check,
  X
} from 'lucide-react';
import { api } from '@/lib/api';
import { useToast } from '@/hooks/use-toast';
import { format } from 'date-fns';

export const Dashboard: React.FC = () => {
  const { user } = useAuth();
  const [myEvents, setMyEvents] = useState<Event[]>([]);
  const [attendingEvents, setAttendingEvents] = useState<Event[]>([]);
  const [invitations, setInvitations] = useState<Invitation[]>([]);
  const [loading, setLoading] = useState(true);
  const { toast } = useToast();

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    try {
      setLoading(true);
      const [myEventsResponse, attendingResponse, invitationsResponse] = await Promise.all([
        api.get('/api/users/events'),
        api.get('/api/users/attending'),
        api.get('/api/users/invitations'),
      ]);

      setMyEvents(myEventsResponse.events || myEventsResponse);
      setAttendingEvents(attendingResponse.events || attendingResponse);
      setInvitations(invitationsResponse.invitations || invitationsResponse);
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to load dashboard data. Please try again.",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const handleInvitationResponse = async (invitationId: number, status: 'accepted' | 'declined') => {
    try {
      await api.put(`/api/invitations/${invitationId}`, { status });
      
      // Remove the invitation from the list
      setInvitations(prev => prev.filter(inv => inv.id !== invitationId));
      
      // If accepted, refresh attending events
      if (status === 'accepted') {
        const attendingResponse = await api.get('/api/users/attending');
        setAttendingEvents(attendingResponse.events || attendingResponse);
      }

      toast({
        title: status === 'accepted' ? "Invitation Accepted" : "Invitation Declined",
        description: `You have ${status} the event invitation.`,
      });
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to respond to invitation. Please try again.",
        variant: "destructive",
      });
    }
  };

  const upcomingMyEvents = myEvents.filter(event => new Date(event.date) > new Date());
  const pastMyEvents = myEvents.filter(event => new Date(event.date) <= new Date());
  const upcomingAttending = attendingEvents.filter(event => new Date(event.date) > new Date());
  const pastAttending = attendingEvents.filter(event => new Date(event.date) <= new Date());
  const pendingInvitations = invitations;

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4"></div>
          <p className="text-muted-foreground">Loading your dashboard...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold text-foreground">Dashboard</h1>
              <p className="text-muted-foreground mt-1">Welcome back, {user?.email}!</p>
            </div>
            <Link to="/events/new">
              <Button size="lg" className="bg-gradient-to-r from-primary to-accent">
                <Plus className="h-4 w-4 mr-2" />
                Create Event
              </Button>
            </Link>
          </div>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <Card>
            <CardContent className="p-6">
              <div className="flex items-center">
                <Calendar className="h-8 w-8 text-primary" />
                <div className="ml-4">
                  <p className="text-sm font-medium text-muted-foreground">My Events</p>
                  <p className="text-2xl font-bold">{myEvents.length}</p>
                </div>
              </div>
            </CardContent>
          </Card>
          
          <Card>
            <CardContent className="p-6">
              <div className="flex items-center">
                <Users className="h-8 w-8 text-success" />
                <div className="ml-4">
                  <p className="text-sm font-medium text-muted-foreground">Attending</p>
                  <p className="text-2xl font-bold">{attendingEvents.length}</p>
                </div>
              </div>
            </CardContent>
          </Card>
          
          <Card>
            <CardContent className="p-6">
              <div className="flex items-center">
                <Mail className="h-8 w-8 text-accent" />
                <div className="ml-4">
                  <p className="text-sm font-medium text-muted-foreground">Pending Invites</p>
                  <p className="text-2xl font-bold">{pendingInvitations.length}</p>
                </div>
              </div>
            </CardContent>
          </Card>
          
          <Card>
            <CardContent className="p-6">
              <div className="flex items-center">
                <TrendingUp className="h-8 w-8 text-warning" />
                <div className="ml-4">
                  <p className="text-sm font-medium text-muted-foreground">Total Attendees</p>
                  <p className="text-2xl font-bold">
                    {myEvents.reduce((sum, event) => sum + event.attendees_count, 0)}
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Pending Invitations */}
        {pendingInvitations.length > 0 && (
          <Card className="mb-8">
            <CardHeader>
              <CardTitle className="flex items-center">
                <Mail className="h-5 w-5 mr-2" />
                Pending Invitations
                <Badge variant="secondary" className="ml-2">
                  {pendingInvitations.length}
                </Badge>
              </CardTitle>
              <CardDescription>
                You have event invitations waiting for your response
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {pendingInvitations.map((invitation) => (
                  <div key={invitation.id} className="flex items-center justify-between p-4 border rounded-lg">
                    <div className="flex items-center space-x-4">
                      <Avatar className="h-10 w-10">
                        <AvatarFallback>
                          {invitation.event.creator.email.charAt(0).toUpperCase()}
                        </AvatarFallback>
                      </Avatar>
                      <div>
                        <h4 className="font-semibold">{invitation.event.name}</h4>
                        <p className="text-sm text-muted-foreground">
                          Invited by {invitation.event.creator.email} • {format(new Date(invitation.event.date), 'MMM d, yyyy')}
                        </p>
                      </div>
                    </div>
                    <div className="flex space-x-2">
                      <Button
                        size="sm"
                        onClick={() => handleInvitationResponse(invitation.id, 'accepted')}
                        className="bg-success hover:bg-success/90"
                      >
                        <Check className="h-4 w-4 mr-1" />
                        Accept
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => handleInvitationResponse(invitation.id, 'declined')}
                      >
                        <X className="h-4 w-4 mr-1" />
                        Decline
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        )}

        {/* Main Content */}
        <Tabs defaultValue="my-events" className="space-y-6">
          <TabsList className="grid w-full grid-cols-2">
            <TabsTrigger value="my-events">My Events</TabsTrigger>
            <TabsTrigger value="attending">Attending</TabsTrigger>
          </TabsList>

          <TabsContent value="my-events" className="space-y-6">
            {/* Upcoming My Events */}
            {upcomingMyEvents.length > 0 && (
              <section>
                <div className="flex items-center justify-between mb-4">
                  <h2 className="text-xl font-semibold text-foreground">Upcoming Events</h2>
                  <Badge variant="outline">{upcomingMyEvents.length}</Badge>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                  {upcomingMyEvents.map((event) => (
                    <EventCard key={event.id} event={event} showRSVP={false} />
                  ))}
                </div>
              </section>
            )}

            {/* Past My Events */}
            {pastMyEvents.length > 0 && (
              <section>
                <div className="flex items-center justify-between mb-4">
                  <h2 className="text-xl font-semibold text-foreground">Past Events</h2>
                  <Badge variant="outline">{pastMyEvents.length}</Badge>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                  {pastMyEvents.map((event) => (
                    <EventCard key={event.id} event={event} showRSVP={false} />
                  ))}
                </div>
              </section>
            )}

            {myEvents.length === 0 && (
              <div className="text-center py-12">
                <Calendar className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
                <h3 className="text-xl font-semibold text-foreground mb-2">No events yet</h3>
                <p className="text-muted-foreground mb-4">
                  Start by creating your first event and inviting people to join!
                </p>
                <Link to="/events/new">
                  <Button>
                    <Plus className="h-4 w-4 mr-2" />
                    Create Your First Event
                  </Button>
                </Link>
              </div>
            )}
          </TabsContent>

          <TabsContent value="attending" className="space-y-6">
            {/* Upcoming Attending Events */}
            {upcomingAttending.length > 0 && (
              <section>
                <div className="flex items-center justify-between mb-4">
                  <h2 className="text-xl font-semibold text-foreground">Upcoming Events</h2>
                  <Badge variant="outline">{upcomingAttending.length}</Badge>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                  {upcomingAttending.map((event) => (
                    <EventCard key={event.id} event={event} />
                  ))}
                </div>
              </section>
            )}

            {/* Past Attending Events */}
            {pastAttending.length > 0 && (
              <section>
                <div className="flex items-center justify-between mb-4">
                  <h2 className="text-xl font-semibold text-foreground">Past Events</h2>
                  <Badge variant="outline">{pastAttending.length}</Badge>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                  {pastAttending.map((event) => (
                    <EventCard key={event.id} event={event} showRSVP={false} />
                  ))}
                </div>
              </section>
            )}

            {attendingEvents.length === 0 && (
              <div className="text-center py-12">
                <Users className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
                <h3 className="text-xl font-semibold text-foreground mb-2">No events yet</h3>
                <p className="text-muted-foreground mb-4">
                  Browse events and RSVP to start building your event calendar!
                </p>
                <Link to="/">
                  <Button>
                    <Calendar className="h-4 w-4 mr-2" />
                    Browse Events
                  </Button>
                </Link>
              </div>
            )}
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
};