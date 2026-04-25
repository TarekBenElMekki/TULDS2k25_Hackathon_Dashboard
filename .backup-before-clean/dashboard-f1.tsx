"use client";

import { useEffect, useState, useMemo } from "react";
import { useRouter } from "next/navigation";
import { teams, subBoards, alerts } from "@/lib/dashboard-data";

const EVENT_DURATION_MS = 5 * 60 * 60 * 1000 + 18 * 60 * 1000 + 42 * 1000;

function formatClock(ms: number) {
  const total = Math.max(0, Math.floor(ms / 1000));
  const hours = String(Math.floor(total / 3600)).padStart(2, "0");
  const minutes = String(Math.floor((total % 3600) / 60)).padStart(2, "0");
  const seconds = String(total % 60).padStart(2, "0");
  return hours + ":" + minutes + ":" + seconds;
}

export default function DashboardF1() {
  const router = useRouter();
  const [timeLeft, setTimeLeft] = useState(EVENT_DURATION_MS);
  const [alertIndex, setAlertIndex] = useState(0);
  const [selectedDriver, setSelectedDriver] = useState<string | null>(null);
  const [carPositions, setCarPositions] = useState<{ [key: string]: number }>({});
  const [notification, setNotification] = useState<{ title: string; message: string } | null>(null);
  const [gifUrl, setGifUrl] = useState<string | null>(null);

  // Timer effect
  useEffect(() => {
    const timer = setInterval(() => {
      setTimeLeft((prev) => Math.max(0, prev - 1000));
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  // Rotating alerts effect
  useEffect(() => {
    const interval = setInterval(() => {
      setAlertIndex((prev) => (prev + 1) % alerts.length);
    }, 8000);
    return () => clearInterval(interval);
  }, []);

  // Animate car positions
  useEffect(() => {
    const interval = setInterval(() => {
      setCarPositions((prev) => {
        const newPositions: { [key: string]: number } = {};
        teams.forEach((team) => {
          const currentProgress = prev[team.code] || (team.progress || 55);
          const movement = (Math.random() - 0.5) * 1.5;
          let newProgress = currentProgress + movement;
          newProgress = Math.max(5, Math.min(98, newProgress));
          newPositions[team.code] = newProgress;
        });
        return newPositions;
      });
    }, 3000);
    return () => clearInterval(interval);
  }, []);

  // Admin command listener
  useEffect(() => {
    const checkForAdminCommands = () => {
      const stored = localStorage.getItem("f1_admin_action");
      if (stored) {
        try {
          const action = JSON.parse(stored);
          const now = Date.now();
          if (now - action.timestamp < 5000) {
            switch (action.action) {
              case "soundtrack":
                setNotification({ title: "RACE CONTROL", message: "Soundtrack playing!" });
                setTimeout(() => setNotification(null), 3000);
                break;
              case "message":
                setNotification({ title: action.data.title || "RACE CONTROL", message: action.data.message });
                setTimeout(() => setNotification(null), 4000);
                break;
              case "gif":
                setGifUrl(action.data.url);
                setTimeout(() => setGifUrl(null), 3000);
                break;
              case "points":
                setNotification({ title: "POINTS UPDATE", message: "Race results are being calculated!" });
                setTimeout(() => setNotification(null), 3000);
                break;
              case "safety_car":
                setNotification({ title: "SAFETY CAR", message: "Safety car deployed on track!" });
                setTimeout(() => setNotification(null), 4000);
                break;
              case "fastest_lap":
                setNotification({ title: "FASTEST LAP", message: "New fastest lap recorded!" });
                setTimeout(() => setNotification(null), 3000);
                break;
            }
          }
          localStorage.removeItem("f1_admin_action");
        } catch(e) {
          console.log("Error parsing admin command");
        }
      }
    };

    const interval = setInterval(checkForAdminCommands, 500);
    return () => clearInterval(interval);
  }, []);

  const clock = useMemo(() => formatClock(timeLeft), [timeLeft]);

  const getCarIcon = (position: number) => {
    if (position > 90) return "Ã°Å¸ÂÂÃ°Å¸ÂÅ½Ã¯Â¸Â";
    if (position > 70) return "Ã°Å¸ÂÅ½Ã¯Â¸ÂÃ°Å¸â€™Â¨";
    if (position > 50) return "Ã°Å¸ÂÅ½Ã¯Â¸Â";
    return "Ã°Å¸ÂÅ½Ã¯Â¸Â";
  };

  return (
    <div className="f1-dashboard">
      {notification && (
        <div className="notification-overlay">
          <div className="notification">
            <div className="notification-title">{notification.title}</div>
            <div className="notification-message">{notification.message}</div>
          </div>
        </div>
      )}
      
      {gifUrl && (
        <div className="gif-overlay">
          <img src={gifUrl} alt="Race moment" />
        </div>
      )}

      <div className="dashboard-grid">
        <header className="f1-header">
          <div className="logo-area">
            <div className="f1-logo">
              F1<span>HACK</span>
            </div>
            <div className="event-name">GRAND PRIX TRACKER 2026</div>
          </div>
          
          <div className="timer-area">
            <div className="timer-label">RACE DURATION</div>
            <div className="timer-value">{clock}</div>
          </div>
          
          <div className="live-indicator">
            <div className="live-dot"></div>
            <div className="live-text">LIVE TIMING</div>
          </div>
        </header>

        <div className="main-content">
          {/* Left Sidebar - Driver Tracker */}
          <div className="driver-sidebar">
            <div className="driver-header">
              <h3>DRIVER TRACKER</h3>
            </div>
            <div className="driver-list">
              {teams.map((team) => (
                <div 
                  key={team.code} 
                  className="driver-item"
                  onClick={() => setSelectedDriver(team.driver)}
                  style={{ background: selectedDriver === team.driver ? "rgba(225,6,0,0.15)" : "transparent" }}
                >
                  <div className="driver-color-bar" style={{ background: team.color }}></div>
                  <div className="driver-pos">{team.rank}</div>
                  <div className="driver-info">
                    <div className="driver-name">{team.driver}</div>
                    <div className="driver-team-name">{team.name}</div>
                  </div>
                  <div className="driver-gap">
                    +{Math.floor(Math.random() * 20)}.{Math.floor(Math.random() * 9)}s
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Center Column */}
          <div className="center-column">
            {/* Main Championship Table */}
            <div className="f1-card">
              <div className="card-header">
                <h2>CHAMPIONSHIP STANDINGS</h2>
                <p>11 teams competing | Full leaderboard</p>
              </div>
              <div className="data-table">
                <table>
                  <thead>
                    <tr>
                      <th>Pos</th>
                      <th>Team</th>
                      <th>Driver</th>
                      <th>Pts</th>
                      <th>Tasks</th>
                    </tr>
                  </thead>
                  <tbody>
                    {teams.map((team) => (
                      <tr key={team.code}>
                        <td className="position">{team.rank}</td>
                        <td>
                          <div className="team-badge">
                            <div className="team-color" style={{ background: team.color }}></div>
                            <span className="team-code">{team.code}</span>
                            <span className="team-name">{team.name}</span>
                          </div>
                        </td>
                        <td>{team.driver}</td>
                        <td className="points">{team.points}</td>
                        <td>{team.tasks}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>

            {/* 6 Mini Boards */}
            <div className="mini-boards-grid">
              {subBoards.map((board) => (
                <div key={board.title} className="mini-board">
                  <div className="mini-board-header">
                    <h4>{board.title}</h4>
                  </div>
                  <div className="mini-board-table">
                    <table>
                      <thead>
                        <tr>
                          <th>Pos</th>
                          <th>Team</th>
                          <th>{board.metric}</th>
                        </tr>
                      </thead>
                      <tbody>
                        {board.rows.slice(0, 6).map((team) => (
                          <tr key={team.code}>
                            <td className="position">{team.rank}</td>
                            <td>
                              <div className="team-badge">
                                <div className="team-color" style={{ background: team.color }}></div>
                                <span className="team-code">{team.code}</span>
                              </div>
                            </td>
                            <td>{board.metric === "Time" ? team.sector1 + "s" : team.points}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Right Sidebar - Race Progress */}
          <div className="goal-tracker">
            <div className="goal-header">
              <h3>Ã°Å¸ÂÂ RACE PROGRESS</h3>
            </div>
            <div className="race-track">
              {teams.map((team) => {
                const progress = carPositions[team.code] || (team.progress || 55);
                return (
                  <div key={team.code} className="track-row">
                    <div className="track-position">{team.rank}</div>
                    <div 
                      className="track-car-icon"
                      style={{ left: progress + "%" }}
                    >
                      {getCarIcon(progress)}
                    </div>
                    <div className="track-team-code">{team.code}</div>
                    <div className="track-progress">{Math.round(progress)}%</div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        <footer className="f1-footer">
          <div>Ã‚Â© 2026 F1 Hackathon Championship | Live Timing | 11 Teams</div>
          <div className="footer-message">
            <span>Ã°Å¸ÂÂ Grand Prix</span>
            <span>Ã°Å¸â€œÅ  Real-time Updates</span>
            <span>Ã°Å¸Å½Â¯ Live Positions</span>
          </div>
        </footer>
      </div>

      <button className="admin-button" onClick={() => router.push("/admin")}>
        Ã°Å¸Å½Â® RACE CONTROL
      </button>
    </div>
  );
}



