package com.sofagames.backend.auth.dto;

import com.sofagames.backend.auth.entity.User;
import com.sofagames.backend.auth.entity.UserProfile;

import java.util.Set;

public class AuthResponse {

    private Long id;
    private String name;
    private String email;
    private String token;
    private Set<UserProfile> profiles;

    // Constructors
    public AuthResponse() {}

    public AuthResponse(User user, String token) {
        this.id = user.getId();
        this.name = user.getName();
        this.email = user.getEmail();
        this.token = token;
        this.profiles = user.getProfiles();
    }

    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getToken() { return token; }
    public void setToken(String token) { this.token = token; }
    public Set<UserProfile> getProfiles() { return profiles; }
    public void setProfiles(Set<UserProfile> profiles) { this.profiles = profiles; }
}