-- ============================================================================
-- Music Tutor Database Schema (MySQL 8.0+)
-- Database: music_tutor_db
-- Supports: Trainer & Trainee Roles, JWT Auth, Exercise Assignments
-- ============================================================================

SET FOREIGN_KEY_CHECKS = 0;

CREATE DATABASE IF NOT EXISTS music_tutor_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE music_tutor_db;

-- ----------------------------------------------------------------------------
-- 1. Table: users (Trainers & Trainees)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) DEFAULT NULL,
    role ENUM('TRAINER', 'TRAINEE') NOT NULL DEFAULT 'TRAINEE',
    trainer_id INT DEFAULT NULL COMMENT 'If role is TRAINEE, points to the managing TRAINER',
    skill_level ENUM('BEGINNER', 'MODERATE', 'PRO') DEFAULT 'BEGINNER',
    avatar_url VARCHAR(255) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (trainer_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- 2. Table: exercises
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS exercises (
    id VARCHAR(50) PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    skill_level ENUM('BEGINNER', 'MODERATE', 'PRO') NOT NULL,
    category ENUM('MIDI', 'AUDIO', 'THEORY') NOT NULL DEFAULT 'MIDI',
    target_bpm INT NOT NULL DEFAULT 80,
    notes_sequence JSON NOT NULL COMMENT 'JSON array of note strings e.g. ["C4", "D4", "E4"]',
    ai_tip TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- 3. Table: trainer_assignments (Exercise Assignments from Trainer to Trainee)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS trainer_assignments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    trainer_id INT NOT NULL,
    trainee_id INT NOT NULL,
    exercise_id VARCHAR(50) NOT NULL,
    status ENUM('PENDING', 'IN_PROGRESS', 'COMPLETED') NOT NULL DEFAULT 'PENDING',
    notes TEXT DEFAULT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (trainer_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (trainee_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- 4. Table: user_progress
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_progress (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    streak_days INT NOT NULL DEFAULT 1,
    total_sessions_played INT NOT NULL DEFAULT 0,
    average_accuracy INT NOT NULL DEFAULT 0,
    badges_count INT NOT NULL DEFAULT 0,
    last_practice_date DATE DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- 5. Table: practice_sessions
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS practice_sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    exercise_id VARCHAR(50) DEFAULT NULL,
    session_type ENUM('MIDI', 'AUDIO') NOT NULL,
    accuracy_score INT NOT NULL DEFAULT 0,
    stability_score INT DEFAULT NULL,
    bpm_played INT DEFAULT NULL,
    duration_seconds INT NOT NULL DEFAULT 60,
    notes_evaluated JSON DEFAULT NULL,
    ai_feedback TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- 6. Table: user_settings
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_settings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    theme_mode ENUM('LIGHT', 'DARK', 'SYSTEM') DEFAULT 'SYSTEM',
    accent_palette_index INT DEFAULT 0,
    tuning_standard VARCHAR(100) DEFAULT 'A4 = 440 Hz (Standard)',
    metronome_count_in TINYINT(1) DEFAULT 1,
    metronome_click TINYINT(1) DEFAULT 1,
    auto_connect_midi TINYINT(1) DEFAULT 1,
    latency_profile VARCHAR(50) DEFAULT 'Low Latency (16ms)',
    audio_feedback TINYINT(1) DEFAULT 1,
    noise_cancellation FLOAT DEFAULT 0.75,
    mic_gain FLOAT DEFAULT 0.8,
    daily_reminders TINYINT(1) DEFAULT 1,
    detailed_ai_tips TINYINT(1) DEFAULT 1,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- SAMPLE SEED DATA (Trainer & Trainees)
-- ============================================================================

-- Seed Demo Trainer Account
INSERT INTO users (id, username, email, password_hash, full_name, role)
VALUES (1, 'Master Instructor', 'trainer@musictutor.ai', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW', 'Prof. Alexander Vance', 'TRAINER')
ON DUPLICATE KEY UPDATE username=VALUES(username);

-- Seed Demo Trainee Account (Managed by Trainer 1)
INSERT INTO users (id, username, email, password_hash, full_name, role, trainer_id, skill_level)
VALUES (2, 'Music Learner', 'student1@musictutor.ai', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW', 'Sarah Jenkins', 'TRAINEE', 1, 'BEGINNER')
ON DUPLICATE KEY UPDATE username=VALUES(username);

-- Seed Trainee Progress
INSERT INTO user_progress (user_id, streak_days, total_sessions_played, average_accuracy, badges_count, last_practice_date)
VALUES (2, 15, 12, 85, 5, CURDATE())
ON DUPLICATE KEY UPDATE streak_days=VALUES(streak_days);

-- Seed Trainee Settings
INSERT INTO user_settings (user_id, theme_mode, accent_palette_index, tuning_standard)
VALUES (2, 'SYSTEM', 0, 'A4 = 440 Hz (Standard)')
ON DUPLICATE KEY UPDATE theme_mode=VALUES(theme_mode);

-- Seed Exercises
INSERT INTO exercises (id, title, description, skill_level, category, target_bpm, notes_sequence, ai_tip) VALUES
('b1', 'Single Key Notes & Pitch Match', 'Practice hitting individual notes with clean pitch accuracy.', 'BEGINNER', 'MIDI', 60, '["C4", "E4", "G4"]', 'Focus on hitting C4 steadily before moving to E4.'),
('b2', 'Middle C Pentascale', '5-note consecutive pentascale drill for beginners.', 'BEGINNER', 'MIDI', 70, '["C4", "D4", "E4", "F4", "G4"]', 'Keep your wrist relaxed while moving finger to finger.'),
('b3', 'C Major Triad Arpeggio', 'Basic 3-note chord breakdown.', 'BEGINNER', 'MIDI', 75, '["C4", "E4", "G4", "C5"]', 'Listen carefully to the octave jump to C5.'),

('m1', 'Full C Major Scale', 'Ascending & descending 8-note major scale drill.', 'MODERATE', 'MIDI', 90, '["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"]', 'Smooth finger crossover on the 4th note (F4).'),
('m2', 'G Major Scale Run', 'Ascending G Major scale with sharp F#4 note.', 'MODERATE', 'MIDI', 95, '["G4", "A4", "B4", "C5", "D5", "E5", "F#5", "G5"]', 'Watch for the sharp note on F#5.'),
('m3', 'A Minor Melodic Pattern', 'Natural minor scale pattern drill.', 'MODERATE', 'MIDI', 85, '["A4", "B4", "C5", "D5", "E5", "F5", "G5", "A5"]', 'Emphasize the minor third interval tone.'),

('p1', 'Chromatic Scale Speed Run', 'Full 12-semitone chromatic exercise at high tempo.', 'PRO', 'MIDI', 120, '["C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4", "C5"]', 'Keep note duration perfectly equal at 120 BPM.'),
('p2', 'Bach Two-Part Invention Fragment', 'Polyphonic counterpoint exercise for advanced fingers.', 'PRO', 'MIDI', 130, '["C5", "B4", "C5", "D5", "E5", "G4", "A4", "B4", "C5"]', 'Maintain rhythm independence between finger transitions.')
ON DUPLICATE KEY UPDATE title=VALUES(title);

-- Seed Assignment from Trainer to Trainee
INSERT INTO trainer_assignments (trainer_id, trainee_id, exercise_id, status, notes)
VALUES (1, 2, 'b2', 'IN_PROGRESS', 'Please practice this 5-note pentascale drill before our next lesson.')
ON DUPLICATE KEY UPDATE status=VALUES(status);

SET FOREIGN_KEY_CHECKS = 1;
