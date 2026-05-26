package com.sofagames.backend.auth.service;

import com.sofagames.backend.auth.dto.AuthResponse;
import com.sofagames.backend.auth.dto.LoginRequest;
import com.sofagames.backend.auth.dto.RegisterRequest;
import com.sofagames.backend.auth.entity.User;
import com.sofagames.backend.auth.entity.UserProfile;
import com.sofagames.backend.auth.repository.UserRepository;
import com.sofagames.backend.config.JwtUtil;
import lombok.AllArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Collections;
import java.util.Optional;

@Service
@AllArgsConstructor
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;

    @Override
    public AuthResponse register(RegisterRequest request) {
        Optional<User> existing = userRepository.findByEmail(request.getEmail());
        if (existing.isPresent()) {
            throw new com.sofagames.backend.auth.exception.EmailAlreadyExistsException(
                    "Email already in use: " + request.getEmail()
            );
        }

        User user = new User();
        user.setName(request.getName());
        user.setEmail(request.getEmail());
        user.setPasswordHash(passwordEncoder.encode(request.getPassword()));

        UserProfile profile = new UserProfile();
        profile.setUser(user);
        profile.setFirstName(request.getName().split(" ")[0]);
        profile.setLastName(request.getName().length() > request.getName().indexOf(" ") + 1 ?
                request.getName().substring(request.getName().indexOf(" ") + 1) : "");

        user.setProfiles(Collections.singleton(profile));

        userRepository.save(user);

        String token = jwtUtil.generateToken(user.getEmail());
        return new AuthResponse(user, token);
    }

    @Override
    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new com.sofagames.backend.auth.exception.InvalidCredentialsException(
                        "Invalid email or password"
                ));

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new com.sofagames.backend.auth.exception.InvalidCredentialsException(
                    "Invalid email or password"
            );
        }

        String token = jwtUtil.generateToken(user.getEmail());
        return new AuthResponse(user, token);
    }
}