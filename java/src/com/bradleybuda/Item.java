package com.bradleybuda;

import java.util.HashSet;
import java.util.Set;

public abstract class Item {
    static final Set<Item> ALL = new HashSet<Item>();
    private final Square square;
    private final Set<Square> observableFrom;
    private final int lastSeen;
    
    public Item(final Square square) {
        this.square = square;
        square.setItem(this);
        observableFrom = square.visibleSquares();
        ALL.add(this);
        lastSeen = AI.getTurnNumber();
    }
    
    public boolean exists() {
        return square.getItem().equals(this);
    }
    
    public void sense() {
        lastSeen = AI.getTurnNumber();
    }
    
    public int timeSinceLastSeen() {
        return AI.getTurnNumber() - lastSeen;
    }
    
    public void destroyIfUnsensed() {
        if (timeSinceLastSeen() == 0)
            return;
        
        
    }
}
