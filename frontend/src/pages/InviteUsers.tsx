import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Event } from '@/types/event';
import { User } from '@/contexts/AuthContext';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Checkbox } from '@/components/ui/checkbox';
import { 
  Search, 
  UserPlus, 
  ArrowLeft, 
  Loader2,
  Send,
  Users,
  Mail
} from 'lucide-react';
import { api } from '@/lib/api';
import { useToast } from '@/hooks/use-toast';

interface SearchUser extends User {
  is_invited: boolean;
  is_attending: boolean;
}

export const InviteUsers: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { toast } = useToast();
  
  const [event, setEvent] = useState<Event | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [searchResults, setSearchResults] = useState<SearchUser[]>([]);
  const [selectedUsers, setSelectedUsers] = useState<number[]>([]);
  const [loading, setLoading] = useState(true);
  const [searching, setSearching] = useState(false);
  const [inviting, setInviting] = useState(false);

  useEffect(() => {
    if (id) {
      fetchEvent();
    }
  }, [id]);

  useEffect(() => {
    const delayedSearch = setTimeout(() => {
      if (searchTerm.trim()) {
        searchUsers();
      } else {
        setSearchResults([]);
      }
    }, 300);

    return () => clearTimeout(delayedSearch);
  }, [searchTerm]);

  const fetchEvent = async () => {
    try {
      setLoading(true);
      const response = await api.get(`/api/events/${id}`);
      setEvent(response.event || response);
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to load event details. Please try again.",
        variant: "destructive",
      });
      navigate('/dashboard');
    } finally {
      setLoading(false);
    }
  };

  const searchUsers = async () => {
    try {
      setSearching(true);
      const response = await api.get(`/api/events/${id}/search_users?q=${encodeURIComponent(searchTerm)}`);
      setSearchResults(response.users || response);
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to search users. Please try again.",
        variant: "destructive",
      });
    } finally {
      setSearching(false);
    }
  };

  const handleUserSelect = (userId: number, checked: boolean) => {
    if (checked) {
      setSelectedUsers(prev => [...prev, userId]);
    } else {
      setSelectedUsers(prev => prev.filter(id => id !== userId));
    }
  };

  const handleInviteUsers = async () => {
    if (selectedUsers.length === 0) {
      toast({
        title: "No users selected",
        description: "Please select at least one user to invite.",
        variant: "destructive",
      });
      return;
    }

    setInviting(true);
    try {
      await api.post(`/api/events/${id}/invitations`, {
        user_ids: selectedUsers
      });

      toast({
        title: "Invitations sent!",
        description: `Successfully sent ${selectedUsers.length} invitation${selectedUsers.length === 1 ? '' : 's'}.`,
      });

      // Reset selections and refresh search results
      setSelectedUsers([]);
      if (searchTerm.trim()) {
        searchUsers();
      }
    } catch (error: any) {
      toast({
        title: "Error",
        description: error.message || "Failed to send invitations. Please try again.",
        variant: "destructive",
      });
    } finally {
      setInviting(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4"></div>
          <p className="text-muted-foreground">Loading event...</p>
        </div>
      </div>
    );
  }

  if (!event) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <h2 className="text-2xl font-bold text-foreground mb-2">Event not found</h2>
          <p className="text-muted-foreground mb-4">The event you're trying to invite users to doesn't exist.</p>
          <Button onClick={() => navigate('/dashboard')}>Back to Dashboard</Button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Back Button */}
        <Button variant="ghost" onClick={() => navigate(`/events/${id}`)} className="mb-6">
          <ArrowLeft className="h-4 w-4 mr-2" />
          Back to Event
        </Button>

        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-foreground">Invite Users</h1>
          <p className="text-muted-foreground mt-2">
            Search for users and invite them to <span className="font-medium">{event.name}</span>
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Search & Results */}
          <div className="lg:col-span-2 space-y-6">
            {/* Search */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center">
                  <Search className="h-5 w-5 mr-2" />
                  Search Users
                </CardTitle>
                <CardDescription>
                  Enter a name or email to search for users to invite
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground h-4 w-4" />
                  <Input
                    placeholder="Search by name or email..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="pl-10"
                  />
                  {searching && (
                    <div className="absolute right-3 top-1/2 transform -translate-y-1/2">
                      <Loader2 className="h-4 w-4 animate-spin text-muted-foreground" />
                    </div>
                  )}
                </div>
              </CardContent>
            </Card>

            {/* Search Results */}
            {searchTerm.trim() && (
              <Card>
                <CardHeader>
                  <CardTitle>Search Results</CardTitle>
                  <CardDescription>
                    {searchResults.length} user{searchResults.length === 1 ? '' : 's'} found
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  {searchResults.length > 0 ? (
                    <div className="space-y-3">
                      {searchResults.map((user) => (
                        <div key={user.id} className="flex items-center justify-between p-3 border rounded-lg">
                          <div className="flex items-center space-x-3">
                            <Checkbox
                              checked={selectedUsers.includes(user.id)}
                              onCheckedChange={(checked) => handleUserSelect(user.id, checked as boolean)}
                              disabled={user.is_invited || user.is_attending}
                            />
                            <Avatar className="h-10 w-10">
                              <AvatarImage src={user.avatar_url} alt={user.name} />
                              <AvatarFallback>
                                {user.name.charAt(0).toUpperCase()}
                              </AvatarFallback>
                            </Avatar>
                            <div className="flex-1 min-w-0">
                              <p className="text-sm font-medium text-foreground truncate">
                                {user.name}
                              </p>
                              <p className="text-xs text-muted-foreground truncate">
                                {user.email}
                              </p>
                            </div>
                          </div>
                          
                          <div className="flex space-x-2">
                            {user.is_attending && (
                              <Badge variant="secondary" className="text-xs">
                                Attending
                              </Badge>
                            )}
                            {user.is_invited && !user.is_attending && (
                              <Badge variant="outline" className="text-xs">
                                Invited
                              </Badge>
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    !searching && (
                      <div className="text-center py-8 text-muted-foreground">
                        <Users className="h-12 w-12 mx-auto mb-4 opacity-50" />
                        <p>No users found</p>
                        <p className="text-sm">Try searching with different keywords</p>
                      </div>
                    )
                  )}
                </CardContent>
              </Card>
            )}

            {!searchTerm.trim() && (
              <Card>
                <CardContent className="py-12">
                  <div className="text-center text-muted-foreground">
                    <Search className="h-12 w-12 mx-auto mb-4 opacity-50" />
                    <p>Start typing to search for users</p>
                    <p className="text-sm">Enter a name or email address to find users to invite</p>
                  </div>
                </CardContent>
              </Card>
            )}
          </div>

          {/* Selected Users Sidebar */}
          <div className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center justify-between">
                  <span>Selected Users</span>
                  <Badge variant="secondary">{selectedUsers.length}</Badge>
                </CardTitle>
                <CardDescription>
                  Users you've selected to invite
                </CardDescription>
              </CardHeader>
              <CardContent>
                {selectedUsers.length > 0 ? (
                  <div className="space-y-3">
                    {selectedUsers.map((userId) => {
                      const user = searchResults.find(u => u.id === userId);
                      if (!user) return null;
                      
                      return (
                        <div key={userId} className="flex items-center space-x-3">
                          <Avatar className="h-8 w-8">
                            <AvatarImage src={user.avatar_url} alt={user.name} />
                            <AvatarFallback>
                              {user.name.charAt(0).toUpperCase()}
                            </AvatarFallback>
                          </Avatar>
                          <div className="flex-1 min-w-0">
                            <p className="text-sm font-medium text-foreground truncate">
                              {user.name}
                            </p>
                            <p className="text-xs text-muted-foreground truncate">
                              {user.email}
                            </p>
                          </div>
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => handleUserSelect(userId, false)}
                            className="text-muted-foreground hover:text-destructive"
                          >
                            ×
                          </Button>
                        </div>
                      );
                    })}
                    
                    <div className="pt-4 border-t">
                      <Button 
                        onClick={handleInviteUsers}
                        disabled={inviting}
                        className="w-full"
                      >
                        {inviting ? (
                          <>
                            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                            Sending...
                          </>
                        ) : (
                          <>
                            <Send className="mr-2 h-4 w-4" />
                            Send Invitations
                          </>
                        )}
                      </Button>
                    </div>
                  </div>
                ) : (
                  <div className="text-center py-6 text-muted-foreground">
                    <Mail className="h-8 w-8 mx-auto mb-2 opacity-50" />
                    <p className="text-sm">No users selected</p>
                    <p className="text-xs">Select users from the search results to invite them</p>
                  </div>
                )}
              </CardContent>
            </Card>

            {/* Event Info */}
            <Card>
              <CardHeader>
                <CardTitle>Event Details</CardTitle>
              </CardHeader>
              <CardContent className="space-y-2">
                <div>
                  <p className="text-sm font-medium text-foreground">{event.name}</p>
                  <p className="text-xs text-muted-foreground">
                    {new Date(event.date).toLocaleDateString()}
                  </p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">
                    {event.attendees_count} attendee{event.attendees_count === 1 ? '' : 's'}
                  </p>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </div>
  );
};