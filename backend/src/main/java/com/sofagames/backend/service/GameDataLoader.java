package com.sofagames.backend.service;

import com.sofagames.backend.model.*;
import com.sofagames.backend.repository.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.ApplicationListener;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

import java.util.*;

@Component
public class GameDataLoader implements ApplicationListener<ApplicationReadyEvent> {

    private final GameRepository gameRepository;
    private final GenreRepository genreRepository;
    private final CategoryRepository categoryRepository;
    private final DeveloperRepository developerRepository;
    private final PublisherRepository publisherRepository;
    private final ScreenshotRepository screenshotRepository;
    private final ObjectMapper objectMapper;

    public GameDataLoader(GameRepository gameRepository,
                          GenreRepository genreRepository,
                          CategoryRepository categoryRepository,
                          DeveloperRepository developerRepository,
                          PublisherRepository publisherRepository,
                          ScreenshotRepository screenshotRepository,
                          ObjectMapper objectMapper) {
        this.gameRepository = gameRepository;
        this.genreRepository = genreRepository;
        this.categoryRepository = categoryRepository;
        this.developerRepository = developerRepository;
        this.publisherRepository = publisherRepository;
        this.screenshotRepository = screenshotRepository;
        this.objectMapper = objectMapper;
    }

    @Override
    public void onApplicationEvent(ApplicationReadyEvent event) {
        if (gameRepository.count() > 0) {
            System.out.println("Database already contains games. Skipping data load.");
            return;
        }

        System.out.println("Loading game data from catalog_final.json...");
        try {
            ClassPathResource resource = new ClassPathResource("catalog_final.json");
            Map<String, Object> catalog = objectMapper.readValue(resource.getInputStream(), Map.class);

            for (Map.Entry<String, Object> entry : catalog.entrySet()) {
                @SuppressWarnings("unchecked")
                Map<String, Object> gameData = (Map<String, Object>) entry.getValue();

                Game game = mapToGame(gameData);
                Game savedGame = gameRepository.save(game);

                // Process genres
                if (gameData.containsKey("genres")) {
                    @SuppressWarnings("unchecked")
                    List<Map<String, Object>> genres = (List<Map<String, Object>>) gameData.get("genres");
                    for (Map<String, Object> genreData : genres) {
                        Integer id = ((Number) genreData.get("id")).intValue();
                        String name = (String) genreData.get("description") != null ? (String) genreData.get("description") : (String) genreData.get("name");
                        Genre genre = genreRepository.findById(id)
                                .orElseGet(() -> {
                                    Genre g = new Genre();
                                    g.setId(id);
                                    g.setName(name != null ? name : "Unknown");
                                    return genreRepository.save(g);
                                });
                        savedGame.getGenres().add(genre);
                    }
                }

                // Process categories
                if (gameData.containsKey("categories")) {
                    @SuppressWarnings("unchecked")
                    List<Map<String, Object>> categories = (List<Map<String, Object>>) gameData.get("categories");
                    for (Map<String, Object> catData : categories) {
                        Integer id = ((Number) catData.get("id")).intValue();
                        String name = (String) catData.get("description") != null ? (String) catData.get("description") : (String) catData.get("name");
                        Category category = categoryRepository.findById(id)
                                .orElseGet(() -> {
                                    Category c = new Category();
                                    c.setId(id);
                                    c.setName(name != null ? name : "Unknown");
                                    return categoryRepository.save(c);
                                });
                        savedGame.getCategories().add(category);
                    }
                }

                // Process developers
                if (gameData.containsKey("developers")) {
                    @SuppressWarnings("unchecked")
                    List<Map<String, Object>> developers = (List<Map<String, Object>>) gameData.get("developers");
                    for (Map<String, Object> devData : developers) {
                        String name = (String) devData.get("name");
                        Developer developer = developerRepository.findByName(name)
                                .orElseGet(() -> {
                                    Developer d = new Developer();
                                    d.setName(name);
                                    return developerRepository.save(d);
                                });
                        savedGame.getDevelopers().add(developer);
                    }
                }

                // Process publishers
                if (gameData.containsKey("publishers")) {
                    @SuppressWarnings("unchecked")
                    List<Map<String, Object>> publishers = (List<Map<String, Object>>) gameData.get("publishers");
                    for (Map<String, Object> pubData : publishers) {
                        String name = (String) pubData.get("name");
                        Publisher publisher = publisherRepository.findByName(name)
                                .orElseGet(() -> {
                                    Publisher p = new Publisher();
                                    p.setName(name);
                                    return publisherRepository.save(p);
                                });
                        savedGame.getPublishers().add(publisher);
                    }
                }

                // Process screenshots
                if (gameData.containsKey("screenshots")) {
                    @SuppressWarnings("unchecked")
                    List<Map<String, Object>> screenshots = (List<Map<String, Object>>) gameData.get("screenshots");
                    for (Map<String, Object> shotData : screenshots) {
                        Screenshot screenshot = new Screenshot();
                        screenshot.setGame(savedGame);
                        screenshot.setSteamId(((Number) shotData.get("id")).intValue());
                        screenshot.setPathThumbnail((String) shotData.get("path_thumbnail"));
                        screenshot.setPathFull((String) shotData.get("path_full"));
                        Integer order = (Integer) shotData.get("display_order");
                        if (order == null) {
                            order = screenshot.getSteamId(); // fallback
                        }
                        screenshot.setDisplayOrder(order);
                        screenshotRepository.save(screenshot);
                    }
                }

                // Save game again with all associations
                gameRepository.save(savedGame);
            }

            System.out.println("Finished loading game data. Total games: " + gameRepository.count());
        } catch (Exception e) {
            System.err.println("Error loading game data: " + e.getMessage());
            e.printStackTrace();
        }
    }

    private Game mapToGame(Map<String, Object> data) {
        Game game = new Game();

        game.setSteamAppId(((Number) data.get("steam_appid")).intValue());
        game.setName((String) data.get("name"));
        game.setShortDescription((String) data.get("short_description"));
        game.setHeaderImage((String) data.get("header_image"));
        game.setCapsuleImage((String) data.get("capsule_image"));
        game.setBackgroundRaw((String) data.get("background_raw"));
        game.setWebsite((String) data.get("website"));
        game.setIsFree((Boolean) data.getOrDefault("is_free", false));

        // price_overview
        if (data.containsKey("price_overview") && data.get("price_overview") != null) {
            @SuppressWarnings("unchecked")
            Map<String, Object> priceOverview = (Map<String, Object>) data.get("price_overview");
            game.setCurrency((String) priceOverview.get("currency"));
            game.setPriceInitial(((Number) priceOverview.getOrDefault("initial", 0)).intValue());
            game.setPriceFinal(((Number) priceOverview.getOrDefault("final", 0)).intValue());
            game.setDiscountPercent(((Number) priceOverview.getOrDefault("discount_percent", 0)).intValue());
        } else {
            game.setCurrency("CLP"); // default
            game.setPriceInitial(0);
            game.setPriceFinal(0);
            game.setDiscountPercent(0);
        }

        // release_date
        if (data.containsKey("release_date") && data.get("release_date") != null) {
            @SuppressWarnings("unchecked")
            Map<String, Object> releaseDate = (Map<String, Object>) data.get("release_date");
            boolean comingSoon = (Boolean) releaseDate.getOrDefault("coming_soon", false);
            game.setComingSoon(comingSoon);
            String dateStr = (String) releaseDate.get("date");
            if (dateStr != null && !dateStr.isEmpty()) {
                // Parse date like "8 MAR 2017"
                try {
                    java.time.format.DateTimeFormatter formatter = java.time.format.DateTimeFormatter.ofPattern("d MMM yyyy", Locale.ENGLISH);
                    game.setReleaseDate(java.time.LocalDate.parse(dateStr, formatter));
                } catch (Exception e) {
                    // If parsing fails, leave null
                }
            }
        }

        game.setRequiredAge(((Number) data.getOrDefault("required_age", 0)).intValue());
        game.setControllerSupport((String) data.get("controller_support"));
        game.setSupportedLanguages((String) data.get("supported_languages"));
        game.setRecommendationsTotal(((Number) data.getOrDefault("recommendations_total", 0)).intValue());
        game.setAchievementsTotal(((Number) data.getOrDefault("achievements_total", 0)).intValue());

        // system_requirements as JSON string
        if (data.containsKey("system_requirements") && data.get("system_requirements") != null) {
            try {
                game.setSystemRequirements(objectMapper.writeValueAsString(data.get("system_requirements")));
            } catch (Exception e) {
                game.setSystemRequirements("{}");
            }
        } else {
            game.setSystemRequirements("{}");
        }

        // createdAt will be set by @CreationTimestamp

        return game;
    }
}
