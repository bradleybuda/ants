package main

import (
	"fmt"
)

type Route []*Square

type SearchNode struct {
	square *Square
	goal   Goal
	route  Route
	next   *SearchNode
}

func NewSearchNode(square *Square, goal Goal, route Route) *SearchNode {
	return &SearchNode{square, goal, route, nil}
}

func (sn *SearchNode) String() string {
	return fmt.Sprintf("[Search for a path to %v at %v with existing route %v]", sn.goal, sn.square, sn.route)
}

type SearchQueue struct {
	buckets    []*SearchNode
	nextBucket int
	length     int
}

func NewSearchQueue() *SearchQueue {
	return &SearchQueue{make([]*SearchNode, 0), 0, 0}
}

func (q *SearchQueue) Len() int {
	return q.length
}

func (q *SearchQueue) Push(node *SearchNode) {
	bucket := len(node.route)

	// make sure the queue is large enough
	for len(q.buckets) <= bucket {
		q.buckets = append(q.buckets, nil)
	}

	// put the node in the right bucket at the head (more efficient that way)
	newNext := q.buckets[bucket]
	q.buckets[bucket] = node
	node.next = newNext

	// point to this bucket if it's higher priority than previous
	if bucket < q.nextBucket {
		q.nextBucket = bucket
	}

	// global counter for statistics
	q.length++
}

func (q *SearchQueue) Pop() *SearchNode {
	// pick the lowest priority bucket
	for q.buckets[q.nextBucket] == nil {
		q.nextBucket++
	}

	// grab the node at that bucket
	node := q.buckets[q.nextBucket]

	// shift the list in the bucket
	q.buckets[q.nextBucket] = node.next

	q.length--
	return node
}
